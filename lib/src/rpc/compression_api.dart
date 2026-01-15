import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';

import '../constants/tree_config.dart';
import '../state/bn254.dart';
import '../state/compressed_account.dart';
import '../state/token_data.dart';
import '../state/tree_info.dart';
import '../state/validity_proof.dart';
import '../token/token_types.dart';
import '../utils/state_tree_utils.dart';
import 'rpc_types.dart';

/// Version for API endpoints.
enum ApiVersion { v1, v2 }

/// Extended Solana RPC client with compression API support.
///
/// The [Rpc] class combines standard Solana RPC functionality with
/// methods for interacting with the Light Protocol compression indexer
/// (Photon API) and the ZK prover.
///
/// ## Example
/// ```dart
/// final rpc = Rpc.create(
///   'https://mainnet.helius-rpc.com?api-key=YOUR_KEY',
/// );
///
/// final accounts = await rpc.getCompressedAccountsByOwner(ownerPubkey);
/// print('Found ${accounts.items.length} compressed accounts');
/// ```
class Rpc implements CompressionApiInterface {
  Rpc._({
    required this.rpcClient,
    required this.compressionApiEndpoint,
    required this.proverEndpoint,
    required this.apiVersion,
  });

  /// Create an RPC instance.
  ///
  /// If [compressionApiEndpoint] is not provided, it defaults to the same
  /// endpoint as the Solana RPC. For local testing, it defaults to the
  /// local Photon endpoint.
  factory Rpc.create(
    String endpoint, {
    String? compressionApiEndpoint,
    String? proverEndpoint,
    ApiVersion apiVersion = ApiVersion.v2,
    Duration timeout = const Duration(seconds: 30),
  }) {
    const localCompressionApiEndpoint = 'http://127.0.0.1:8784';
    const localProverEndpoint = 'http://127.0.0.1:3001';

    final isLocal = isLocalTest(endpoint);

    return Rpc._(
      rpcClient: RpcClient(endpoint, timeout: timeout),
      compressionApiEndpoint:
          compressionApiEndpoint ??
          (isLocal ? localCompressionApiEndpoint : endpoint),
      proverEndpoint:
          proverEndpoint ?? (isLocal ? localProverEndpoint : endpoint),
      apiVersion: apiVersion,
    );
  }

  /// The underlying Solana RPC client.
  final RpcClient rpcClient;

  /// Endpoint for the compression API (Photon).
  final String compressionApiEndpoint;

  /// Endpoint for the ZK prover.
  final String proverEndpoint;

  /// API version to use.
  final ApiVersion apiVersion;

  /// Cached state tree infos.
  List<TreeInfo>? _cachedStateTreeInfos;
  DateTime? _lastStateTreeFetch;
  static const _cacheTtl = Duration(hours: 1);

  /// Get default state tree infos for local testing.
  List<TreeInfo> _localTestActiveStateTreeInfos() => [
    TreeInfo(
      tree: DefaultTestStateTreeAccounts.batchStateTree,
      queue: DefaultTestStateTreeAccounts.batchStateTree,
      treeType: TreeType.stateV2,
    ),
  ];

  /// Whether to use V2 API endpoints.
  bool get isV2 => apiVersion == ApiVersion.v2;

  /// Get the versioned endpoint name.
  String _versionedEndpoint(String base) => isV2 ? '${base}V2' : base;

  /// Make an RPC request to the compression API.
  Future<Map<String, dynamic>> _compressionRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = await http.post(
      Uri.parse(compressionApiEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 'dart-light-sdk',
        'method': method,
        'params': params,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error')) {
      final error = json['error'] as Map<String, dynamic>;
      throw Exception('RPC error: ${error['message']}');
    }

    return json['result'] as Map<String, dynamic>;
  }

  @override
  Future<List<TreeInfo>> getStateTreeInfos() async {
    // Return cached if valid
    if (_cachedStateTreeInfos != null && _lastStateTreeFetch != null) {
      if (DateTime.now().difference(_lastStateTreeFetch!) < _cacheTtl) {
        return _cachedStateTreeInfos!;
      }
    }

    // For local testing, return defaults
    if (isLocalTest(compressionApiEndpoint)) {
      return _localTestActiveStateTreeInfos();
    }

    // Fetch from lookup tables
    final infos = await fetchStateTreeInfosFromLookupTables(rpcClient);
    _cachedStateTreeInfos = infos;
    _lastStateTreeFetch = DateTime.now();

    return infos;
  }

  @override
  Future<TreeInfo> getAddressTreeInfoV2() async => TreeInfo(
    tree: DefaultTestStateTreeAccounts.batchAddressTree,
    queue: DefaultTestStateTreeAccounts.batchAddressTree,
    treeType: TreeType.addressV2,
  );

  @override
  Future<CompressedAccountWithMerkleContext?> getCompressedAccount({
    BN254? address,
    BN254? hash,
  }) async {
    if (hash == null && address == null) {
      throw ArgumentError('Either hash or address must be provided');
    }
    if (hash != null && address != null) {
      throw ArgumentError('Only one of hash or address must be provided');
    }

    final result =
        await _compressionRequest(_versionedEndpoint('getCompressedAccount'), {
          if (hash != null) 'hash': hash.toBase58(),
          if (address != null) 'address': address.toBase58(),
        });

    final value = result['value'];
    if (value == null) return null;

    return _parseCompressedAccount(value as Map<String, dynamic>);
  }

  @override
  Future<BigInt> getCompressedBalance({BN254? address, BN254? hash}) async {
    if (hash == null && address == null) {
      throw ArgumentError('Either hash or address must be provided');
    }

    final result = await _compressionRequest('getCompressedBalance', {
      if (hash != null) 'hash': hash.toBase58(),
      if (address != null) 'address': address.toBase58(),
    });

    final value = result['value'];
    if (value == null) return BigInt.zero;

    return BigInt.parse(value.toString());
  }

  @override
  Future<BigInt> getCompressedBalanceByOwner(Ed25519HDPublicKey owner) async {
    final result = await _compressionRequest('getCompressedBalanceByOwner', {
      'owner': owner.toBase58(),
    });

    final value = result['value'];
    if (value == null) return BigInt.zero;

    return BigInt.parse(value.toString());
  }

  @override
  Future<MerkleContextWithMerkleProof> getCompressedAccountProof(
    BN254 hash,
  ) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getCompressedAccountProof'),
      {'hash': hash.toBase58()},
    );

    final value = result['value'] as Map<String, dynamic>;
    return _parseMerkleProof(value);
  }

  @override
  Future<List<CompressedAccountWithMerkleContext>>
  getMultipleCompressedAccounts(List<BN254> hashes) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getMultipleCompressedAccounts'),
      {'hashes': hashes.map((h) => h.toBase58()).toList()},
    );

    final items =
        (result['value']['items'] as List<dynamic>)
            .map(
              (item) => _parseCompressedAccount(item as Map<String, dynamic>),
            )
            .toList();

    return items;
  }

  @override
  Future<List<MerkleContextWithMerkleProof>> getMultipleCompressedAccountProofs(
    List<BN254> hashes,
  ) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getMultipleCompressedAccountProofs'),
      {'hashes': hashes.map((h) => h.toBase58()).toList()},
    );

    final proofs =
        (result['value'] as List<dynamic>)
            .map((item) => _parseMerkleProof(item as Map<String, dynamic>))
            .toList();

    return proofs;
  }

  @override
  Future<ValidityProofWithContext> getValidityProof({
    List<BN254>? hashes,
    List<BN254>? newAddresses,
  }) async {
    final result =
        await _compressionRequest(_versionedEndpoint('getValidityProof'), {
          if (hashes != null && hashes.isNotEmpty)
            'hashes': hashes.map((h) => h.toBase58()).toList(),
          if (newAddresses != null && newAddresses.isNotEmpty)
            'newAddresses': newAddresses.map((a) => a.toBase58()).toList(),
        });

    return _parseValidityProof(result['value'] as Map<String, dynamic>);
  }

  @override
  Future<ValidityProofWithContext> getValidityProofV0({
    List<HashWithTree>? hashes,
    List<AddressWithTree>? newAddresses,
  }) async {
    final result = await _compressionRequest('getValidityProof', {
      if (hashes != null)
        'hashes':
            hashes
                .map(
                  (h) => {
                    'hash': h.hash.toBase58(),
                    'tree': h.tree.toBase58(),
                    'queue': h.queue.toBase58(),
                  },
                )
                .toList(),
      if (newAddresses != null)
        'newAddresses':
            newAddresses
                .map(
                  (a) => {
                    'address': a.address.toBase58(),
                    'tree': a.tree.toBase58(),
                    'queue': a.queue.toBase58(),
                  },
                )
                .toList(),
    });

    return _parseValidityProof(result['value'] as Map<String, dynamic>);
  }

  @override
  Future<WithCursor<List<CompressedAccountWithMerkleContext>>>
  getCompressedAccountsByOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
    List<MemcmpFilter>? filters,
  }) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getCompressedAccountsByOwner'),
      {
        'owner': owner.toBase58(),
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
        if (filters != null) 'filters': filters.map((f) => f.toJson()).toList(),
      },
    );

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) => _parseCompressedAccount(item as Map<String, dynamic>),
            )
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<WithCursor<List<ParsedTokenAccount>>>
  getCompressedTokenAccountsByOwner(
    Ed25519HDPublicKey owner, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  }) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getCompressedTokenAccountsByOwner'),
      {
        'owner': owner.toBase58(),
        if (mint != null) 'mint': mint.toBase58(),
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map((item) => _parseTokenAccount(item as Map<String, dynamic>))
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<WithCursor<List<ParsedTokenAccount>>>
  getCompressedTokenAccountsByDelegate(
    Ed25519HDPublicKey delegate, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  }) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getCompressedTokenAccountsByDelegate'),
      {
        'delegate': delegate.toBase58(),
        if (mint != null) 'mint': mint.toBase58(),
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map((item) => _parseTokenAccount(item as Map<String, dynamic>))
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<BigInt> getCompressedTokenAccountBalance(BN254 hash) async {
    final result = await _compressionRequest(
      'getCompressedTokenAccountBalance',
      {'hash': hash.toBase58()},
    );

    final value = result['value'] as Map<String, dynamic>;
    return BigInt.parse(value['amount'].toString());
  }

  @override
  Future<WithCursor<List<TokenBalance>>> getCompressedTokenBalancesByOwner(
    Ed25519HDPublicKey owner, {
    Ed25519HDPublicKey? mint,
    String? cursor,
    int? limit,
  }) async {
    final result = await _compressionRequest(
      isV2
          ? 'getCompressedTokenBalancesByOwnerV2'
          : 'getCompressedTokenBalancesByOwner',
      {
        'owner': owner.toBase58(),
        if (mint != null) 'mint': mint.toBase58(),
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );

    final value = result['value'] as Map<String, dynamic>;
    final itemsKey = isV2 ? 'items' : 'tokenBalances';
    final items =
        (value[itemsKey] as List<dynamic>)
            .map(
              (item) => TokenBalance(
                balance: BigInt.parse(
                  (item['balance'] ?? item['amount']).toString(),
                ),
                mint: Ed25519HDPublicKey.fromBase58(item['mint'] as String),
              ),
            )
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<CompressedTransaction?> getTransactionWithCompressionInfo(
    String signature,
  ) async {
    final result = await _compressionRequest(
      _versionedEndpoint('getTransactionWithCompressionInfo'),
      {'signature': signature},
    );

    if (result['transaction'] == null) return null;

    final compressionInfo =
        (result['compressionInfo'] as Map<String, dynamic>? ?? const {});
    final treeInfos = await getStateTreeInfos();

    final closedAccounts = <ClosedAccountInfo>[];
    final openedAccounts = <OpenedAccountInfo>[];

    if (isV2) {
      for (final item
          in (compressionInfo['closedAccounts'] as List<dynamic>? ??
              const [])) {
        closedAccounts.add(_parseClosedAccountV2(item as Map<String, dynamic>));
      }

      for (final item
          in (compressionInfo['openedAccounts'] as List<dynamic>? ??
              const [])) {
        openedAccounts.add(_parseOpenedAccountV2(item as Map<String, dynamic>));
      }
    } else {
      for (final item
          in (compressionInfo['closedAccounts'] as List<dynamic>? ??
              const [])) {
        closedAccounts.add(
          _parseClosedAccountV1(item as Map<String, dynamic>, treeInfos),
        );
      }

      for (final item
          in (compressionInfo['openedAccounts'] as List<dynamic>? ??
              const [])) {
        openedAccounts.add(
          _parseOpenedAccountV1(item as Map<String, dynamic>, treeInfos),
        );
      }
    }

    final preTokenBalances = _aggregateTokenBalances(
      closedAccounts.map((a) => a.maybeTokenData),
    );
    final postTokenBalances = _aggregateTokenBalances(
      openedAccounts.map((a) => a.maybeTokenData),
    );

    return CompressedTransaction(
      closedAccounts: closedAccounts,
      openedAccounts: openedAccounts,
      transaction: result['transaction'],
      preTokenBalances: preTokenBalances,
      postTokenBalances: postTokenBalances,
    );
  }

  @override
  Future<List<SignatureWithMetadata>> getCompressionSignaturesForAccount(
    BN254 hash,
  ) async {
    final result = await _compressionRequest(
      'getCompressionSignaturesForAccount',
      {'hash': hash.toBase58()},
    );

    final items =
        (result['value']['items'] as List<dynamic>)
            .map(
              (item) => SignatureWithMetadata(
                signature: item['signature'] as String,
                slot: item['slot'] as int,
                blockTime: item['blockTime'] as int,
              ),
            )
            .toList();

    return items;
  }

  @override
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForAddress(
    Ed25519HDPublicKey address, {
    String? cursor,
    int? limit,
  }) async {
    final result =
        await _compressionRequest('getCompressionSignaturesForAddress', {
          'address': address.toBase58(),
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        });

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) => SignatureWithMetadata(
                signature: item['signature'] as String,
                slot: item['slot'] as int,
                blockTime: item['blockTime'] as int,
              ),
            )
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
  }) async {
    final result =
        await _compressionRequest('getCompressionSignaturesForOwner', {
          'owner': owner.toBase58(),
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        });

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) => SignatureWithMetadata(
                signature: item['signature'] as String,
                slot: item['slot'] as int,
                blockTime: item['blockTime'] as int,
              ),
            )
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<WithCursor<List<SignatureWithMetadata>>>
  getCompressionSignaturesForTokenOwner(
    Ed25519HDPublicKey owner, {
    String? cursor,
    int? limit,
  }) async {
    final result =
        await _compressionRequest('getCompressionSignaturesForTokenOwner', {
          'owner': owner.toBase58(),
          if (cursor != null) 'cursor': cursor,
          if (limit != null) 'limit': limit,
        });

    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) =>
                  SignatureWithMetadata.fromJson(item as Map<String, dynamic>),
            )
            .toList();

    return WithCursor(items: items, cursor: value['cursor'] as String?);
  }

  @override
  Future<String> getIndexerHealth() async {
    final result = await _compressionRequest('getIndexerHealth', {});
    return result['value'] as String? ?? 'ok';
  }

  @override
  Future<int> getIndexerSlot() async {
    final result = await _compressionRequest('getIndexerSlot', {});
    return result['value'] as int;
  }

  @override
  Future<bool> confirmTransactionIndexed(int slot) async {
    final isLocal = isLocalTest(compressionApiEndpoint);
    final timeout = Duration(milliseconds: isLocal ? 10000 : 20000);
    final interval = Duration(milliseconds: isLocal ? 100 : 200);
    final start = DateTime.now();

    while (true) {
      final current = await getIndexerSlot();
      if (current >= slot) return true;
      if (DateTime.now().difference(start) > timeout) {
        throw Exception(
          'Timeout: indexer slot did not reach $slot within '
          '${timeout.inSeconds}s (current: $current)',
        );
      }
      await Future<void>.delayed(interval);
    }
  }

  @override
  Future<WithContext<WithCursor<List<CompressedMintTokenHolders>>>>
  getCompressedMintTokenHolders(
    Ed25519HDPublicKey mint, {
    String? cursor,
    int? limit,
  }) async {
    final result = await _compressionRequest('getCompressedMintTokenHolders', {
      'mint': mint.toBase58(),
      if (cursor != null) 'cursor': cursor,
      if (limit != null) 'limit': limit,
    });

    final context = RpcContext.fromJson(
      result['context'] as Map<String, dynamic>,
    );
    final value = result['value'] as Map<String, dynamic>;

    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) => CompressedMintTokenHolders.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();

    return WithContext(
      context: context,
      value: WithCursor(items: items, cursor: value['cursor'] as String?),
    );
  }

  @override
  Future<LatestNonVotingSignaturesPaginated> getLatestCompressionSignatures({
    String? cursor,
    int? limit,
  }) async {
    final result = await _compressionRequest('getLatestCompressionSignatures', {
      if (limit != null) 'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });

    final context = RpcContext.fromJson(
      result['context'] as Map<String, dynamic>,
    );
    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) =>
                  SignatureWithMetadata.fromJson(item as Map<String, dynamic>),
            )
            .toList();

    return LatestNonVotingSignaturesPaginated(
      context: context,
      items: items,
      cursor: value['cursor'] as String?,
    );
  }

  @override
  Future<LatestNonVotingSignatures> getLatestNonVotingSignatures({
    int? limit,
    String? cursor,
  }) async {
    final result = await _compressionRequest('getLatestNonVotingSignatures', {
      if (limit != null) 'limit': limit,
      if (cursor != null) 'cursor': cursor,
    });

    final context = RpcContext.fromJson(
      result['context'] as Map<String, dynamic>,
    );
    final value = result['value'] as Map<String, dynamic>;
    final items =
        (value['items'] as List<dynamic>)
            .map(
              (item) =>
                  LatestSignatureItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();

    return LatestNonVotingSignatures(context: context, items: items);
  }

  // Helper methods for transaction parsing

  ClosedAccountInfo _parseClosedAccountV2(Map<String, dynamic> json) {
    final accountWrapper = json['account'] as Map<String, dynamic>;
    final accountJson = accountWrapper['account'] as Map<String, dynamic>;

    final nullifierMetadata =
        accountWrapper['nullifier'] != null && accountWrapper['txHash'] != null
            ? NullifierMetadata(
              nullifier: BN254.fromBase58(
                accountWrapper['nullifier'] as String,
              ),
              txHash: BN254.fromBase58(accountWrapper['txHash'] as String),
            )
            : null;

    return ClosedAccountInfo(
      account: _buildCompressedAccountV2(accountJson),
      maybeTokenData: _parseOptionalTokenData(
        json['optionalTokenData'] as Map<String, dynamic>?,
      ),
      nullifierMetadata: nullifierMetadata,
    );
  }

  OpenedAccountInfo _parseOpenedAccountV2(Map<String, dynamic> json) =>
      OpenedAccountInfo(
        account: _buildCompressedAccountV2(
          json['account'] as Map<String, dynamic>,
        ),
        maybeTokenData: _parseOptionalTokenData(
          json['optionalTokenData'] as Map<String, dynamic>?,
        ),
      );

  ClosedAccountInfo _parseClosedAccountV1(
    Map<String, dynamic> json,
    List<TreeInfo> treeInfos,
  ) => ClosedAccountInfo(
    account: _buildCompressedAccountV1(
      json['account'] as Map<String, dynamic>,
      treeInfos,
    ),
    maybeTokenData: _parseOptionalTokenData(
      json['optionalTokenData'] as Map<String, dynamic>?,
    ),
  );

  OpenedAccountInfo _parseOpenedAccountV1(
    Map<String, dynamic> json,
    List<TreeInfo> treeInfos,
  ) => OpenedAccountInfo(
    account: _buildCompressedAccountV1(
      json['account'] as Map<String, dynamic>,
      treeInfos,
    ),
    maybeTokenData: _parseOptionalTokenData(
      json['optionalTokenData'] as Map<String, dynamic>?,
    ),
  );

  CompressedAccountWithMerkleContext _buildCompressedAccountV2(
    Map<String, dynamic> json,
  ) {
    final merkleContext = json['merkleContext'] as Map<String, dynamic>?;
    final tree =
        merkleContext != null
            ? merkleContext['tree'] as String
            : json['tree'] as String;
    final queue =
        merkleContext != null
            ? (merkleContext['queue'] ?? merkleContext['tree']) as String
            : tree;

    final treeInfo = TreeInfo(
      tree: Ed25519HDPublicKey.fromBase58(tree),
      queue: Ed25519HDPublicKey.fromBase58(queue),
      treeType: TreeType.stateV2,
    );

    return createCompressedAccountWithMerkleContext(
      owner: Ed25519HDPublicKey.fromBase58(json['owner'] as String),
      lamports: BigInt.parse(json['lamports'].toString()),
      hash: BN254.fromBase58(json['hash'] as String),
      treeInfo: treeInfo,
      leafIndex: json['leafIndex'] as int,
      address: (json['address'] as List<dynamic>?)?.cast<int>(),
      proveByIndex: json['proveByIndex'] as bool? ?? false,
    );
  }

  CompressedAccountWithMerkleContext _buildCompressedAccountV1(
    Map<String, dynamic> json,
    List<TreeInfo> treeInfos,
  ) {
    final tree = Ed25519HDPublicKey.fromBase58(json['tree'] as String);
    final treeInfo =
        _findTreeInfoByPubkey(treeInfos, tree) ??
        TreeInfo(tree: tree, queue: tree, treeType: TreeType.stateV1);

    return createCompressedAccountWithMerkleContext(
      owner: Ed25519HDPublicKey.fromBase58(json['owner'] as String),
      lamports: BigInt.parse(json['lamports'].toString()),
      hash: BN254.fromBase58(json['hash'] as String),
      treeInfo: treeInfo,
      leafIndex: json['leafIndex'] as int,
      address: (json['address'] as List<dynamic>?)?.cast<int>(),
    );
  }

  TreeInfo? _findTreeInfoByPubkey(
    List<TreeInfo> treeInfos,
    Ed25519HDPublicKey tree,
  ) {
    for (final info in treeInfos) {
      if (info.tree == tree) return info;
    }
    return null;
  }

  TokenData? _parseOptionalTokenData(Map<String, dynamic>? json) {
    if (json == null) return null;

    final stateStr = json['state'] as String?;
    final tokenState =
        stateStr != null
            ? TokenAccountState.values.firstWhere(
              (s) => s.name == stateStr,
              orElse: () => TokenAccountState.initialized,
            )
            : TokenAccountState.initialized;

    return TokenData(
      mint: Ed25519HDPublicKey.fromBase58(json['mint'] as String),
      owner: Ed25519HDPublicKey.fromBase58(json['owner'] as String),
      amount: BigInt.parse(json['amount'].toString()),
      state: tokenState,
      delegate:
          json['delegate'] != null
              ? Ed25519HDPublicKey.fromBase58(json['delegate'] as String)
              : null,
    );
  }

  List<TokenBalanceInfo>? _aggregateTokenBalances(
    Iterable<TokenData?> tokenDatas,
  ) {
    final balances = <String, TokenBalanceInfo>{};

    for (final token in tokenDatas) {
      if (token == null) continue;
      final key = '${token.owner.toBase58()}_${token.mint.toBase58()}';
      final existing = balances[key];

      balances[key] =
          existing != null
              ? TokenBalanceInfo(
                owner: existing.owner,
                mint: existing.mint,
                amount: existing.amount + token.amount,
              )
              : TokenBalanceInfo(
                owner: token.owner,
                mint: token.mint,
                amount: token.amount,
              );
    }

    return balances.isEmpty ? null : balances.values.toList();
  }

  // Helper methods for parsing responses

  CompressedAccountWithMerkleContext _parseCompressedAccount(
    Map<String, dynamic> json,
  ) {
    final merkleContext =
        isV2 ? json['merkleContext'] as Map<String, dynamic> : null;

    final treeKey = isV2 ? merkleContext!['tree'] : json['tree'];
    final queueKey = isV2 ? merkleContext!['queue'] : json['tree'];

    return CompressedAccount(
      owner: Ed25519HDPublicKey.fromBase58(json['owner'] as String),
      lamports: BigInt.parse(json['lamports'].toString()),
      hash: BN254.fromBase58(json['hash'] as String),
      treeInfo: TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58(treeKey as String),
        queue: Ed25519HDPublicKey.fromBase58(queueKey as String),
        treeType: isV2 ? TreeType.stateV2 : TreeType.stateV1,
      ),
      leafIndex: json['leafIndex'] as int,
      address:
          json['address'] != null
              ? Ed25519HDPublicKey.fromBase58(
                json['address'] as String,
              ).bytes.toList()
              : null,
      proveByIndex: isV2 ? (json['proveByIndex'] as bool? ?? false) : false,
    );
  }

  MerkleContextWithMerkleProof _parseMerkleProof(Map<String, dynamic> json) {
    final treeContext =
        isV2 ? json['treeContext'] as Map<String, dynamic> : null;

    final tree =
        isV2 ? treeContext!['tree'] as String : json['merkleTree'] as String;

    return MerkleContextWithMerkleProof(
      hash: BN254.fromBase58(json['hash'] as String),
      treeInfo: TreeInfo(
        tree: Ed25519HDPublicKey.fromBase58(tree),
        queue: Ed25519HDPublicKey.fromBase58(
          isV2 ? treeContext!['queue'] as String : tree,
        ),
        treeType: isV2 ? TreeType.stateV2 : TreeType.stateV1,
      ),
      leafIndex: json['leafIndex'] as int,
      merkleProof:
          (json['proof'] as List<dynamic>)
              .map((p) => BN254.fromBase58(p as String))
              .toList(),
      rootIndex: (json['rootSeq'] as int) % 2400,
      root: BN254.fromBase58(json['root'] as String),
      proveByIndex: isV2 ? (json['proveByIndex'] as bool? ?? false) : false,
    );
  }

  ValidityProofWithContext _parseValidityProof(Map<String, dynamic> json) {
    final compressedProof = json['compressedProof'] as Map<String, dynamic>?;
    final proof =
        compressedProof != null
            ? CompressedProof(
              a: (compressedProof['a'] as List<dynamic>).cast<int>(),
              b: (compressedProof['b'] as List<dynamic>).cast<int>(),
              c: (compressedProof['c'] as List<dynamic>).cast<int>(),
            )
            : null;

    if (isV2) {
      final accounts = json['accounts'] as List<dynamic>? ?? [];
      final addresses = json['addresses'] as List<dynamic>? ?? [];

      return ValidityProofWithContext(
        compressedProof: proof,
        roots: [
          ...accounts.map((a) => BN254.fromBase58(a['root'] as String)),
          ...addresses.map((a) => BN254.fromBase58(a['root'] as String)),
        ],
        rootIndices: [
          ...accounts.map((a) => (a['rootIndex']['rootIndex'] as int)),
          ...addresses.map((a) => a['rootIndex'] as int),
        ],
        leafIndices: accounts.map((a) => a['leafIndex'] as int).toList(),
        leaves:
            accounts.map((a) => BN254.fromBase58(a['hash'] as String)).toList(),
        treeInfos:
            accounts.map((a) {
              final ctx = a['merkleContext'] as Map<String, dynamic>;
              return TreeInfo(
                tree: Ed25519HDPublicKey.fromBase58(ctx['tree'] as String),
                queue: Ed25519HDPublicKey.fromBase58(ctx['queue'] as String),
                treeType: TreeType.stateV2,
              );
            }).toList(),
        proveByIndices:
            accounts
                .map((a) => (a['rootIndex']['proveByIndex'] as bool?) ?? false)
                .toList(),
      );
    } else {
      return ValidityProofWithContext(
        compressedProof: proof,
        roots:
            (json['roots'] as List<dynamic>)
                .map((r) => BN254.fromBase58(r as String))
                .toList(),
        rootIndices: (json['rootIndices'] as List<dynamic>).cast<int>(),
        leafIndices: (json['leafIndices'] as List<dynamic>).cast<int>(),
        leaves:
            (json['leaves'] as List<dynamic>)
                .map((l) => BN254.fromBase58(l as String))
                .toList(),
        treeInfos:
            (json['merkleTrees'] as List<dynamic>).map((t) {
              final treeStr = t as String;
              return TreeInfo(
                tree: Ed25519HDPublicKey.fromBase58(treeStr),
                queue: Ed25519HDPublicKey.fromBase58(treeStr),
                treeType: TreeType.stateV1,
              );
            }).toList(),
        proveByIndices: List.filled(
          (json['leafIndices'] as List<dynamic>).length,
          false,
        ),
      );
    }
  }

  ParsedTokenAccount _parseTokenAccount(Map<String, dynamic> json) {
    final accountData = json['account'] as Map<String, dynamic>;
    final tokenData = json['tokenData'] as Map<String, dynamic>;

    final stateStr = tokenData['state'] as String;
    final state = TokenAccountState.values.firstWhere(
      (s) => s.name == stateStr,
      orElse: () => TokenAccountState.initialized,
    );

    return ParsedTokenAccount(
      compressedAccount: _parseCompressedAccount(accountData),
      parsed: TokenData(
        mint: Ed25519HDPublicKey.fromBase58(tokenData['mint'] as String),
        owner: Ed25519HDPublicKey.fromBase58(tokenData['owner'] as String),
        amount: BigInt.parse(tokenData['amount'].toString()),
        state: state,
        delegate:
            tokenData['delegate'] != null
                ? Ed25519HDPublicKey.fromBase58(tokenData['delegate'] as String)
                : null,
      ),
    );
  }
}
