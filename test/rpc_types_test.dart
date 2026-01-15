import 'package:test/test.dart';
import 'package:solana/solana.dart';

import 'package:light_sdk/light_sdk.dart';

void main() {
  group('RpcContext', () {
    test('creates RPC context with slot', () {
      final context = RpcContext(slot: 123456789);

      expect(context.slot, equals(123456789));
    });

    test('supports zero slot', () {
      final context = RpcContext(slot: 0);

      expect(context.slot, equals(0));
    });

    test('multiple instances have same slot value', () {
      final context1 = RpcContext(slot: 12345);
      final context2 = RpcContext(slot: 12345);

      expect(context1.slot, equals(context2.slot));
    });
  });

  group('WithContext', () {
    test('wraps value with context', () {
      final context = RpcContext(slot: 100);
      final value = 'test-data';

      final wrapped = WithContext(context: context, value: value);

      expect(wrapped.context, equals(context));
      expect(wrapped.value, equals(value));
      expect(wrapped.context.slot, equals(100));
    });

    test('works with different value types', () {
      final context = RpcContext(slot: 200);

      final intWrapped = WithContext(context: context, value: 42);
      expect(intWrapped.value, equals(42));

      final listWrapped = WithContext(context: context, value: [1, 2, 3]);
      expect(listWrapped.value, equals([1, 2, 3]));

      final boolWrapped = WithContext(context: context, value: true);
      expect(boolWrapped.value, equals(true));
    });

    test('supports null value', () {
      final context = RpcContext(slot: 300);
      final wrapped = WithContext<String?>(context: context, value: null);

      expect(wrapped.value, isNull);
      expect(wrapped.context.slot, equals(300));
    });
  });

  group('WithCursor', () {
    test('wraps items with cursor', () {
      final items = ['item1', 'item2', 'item3'];
      const cursor = 'next-page-token';

      final wrapped = WithCursor(items: items, cursor: cursor);

      expect(wrapped.items, equals(items));
      expect(wrapped.cursor, equals(cursor));
    });

    test('supports null cursor (last page)', () {
      final items = ['item1', 'item2'];

      final wrapped = WithCursor(items: items, cursor: null);

      expect(wrapped.items, equals(items));
      expect(wrapped.cursor, isNull);
    });

    test('supports empty items list', () {
      final wrapped = WithCursor<List<String>>(items: <String>[], cursor: null);

      expect(wrapped.items, isEmpty);
      expect(wrapped.cursor, isNull);
    });

    test('supports property access', () {
      final items = ['a', 'b'];
      const cursor = 'cursor-123';

      final wrapped = WithCursor(items: items, cursor: cursor);

      expect(wrapped.items, equals(items));
      expect(wrapped.cursor, equals(cursor));
    });
  });

  group('MemcmpFilter', () {
    test('creates filter with offset and bytes', () {
      final filter = MemcmpFilter(offset: 0, bytes: 'base58-encoded-data');

      expect(filter.offset, equals(0));
      expect(filter.bytes, equals('base58-encoded-data'));
    });

    test('supports non-zero offset', () {
      final filter = MemcmpFilter(offset: 32, bytes: 'filter-data');

      expect(filter.offset, equals(32));
    });

    test('multiple instances have same property values', () {
      final filter1 = MemcmpFilter(offset: 8, bytes: 'data');
      final filter2 = MemcmpFilter(offset: 8, bytes: 'data');

      expect(filter1.offset, equals(filter2.offset));
      expect(filter1.bytes, equals(filter2.bytes));
    });
  });

  group('DataSlice', () {
    test('creates data slice with offset and length', () {
      final slice = DataSlice(offset: 0, length: 100);

      expect(slice.offset, equals(0));
      expect(slice.length, equals(100));
    });

    test('supports non-zero offset', () {
      final slice = DataSlice(offset: 50, length: 32);

      expect(slice.offset, equals(50));
      expect(slice.length, equals(32));
    });

    test('multiple instances have same property values', () {
      final slice1 = DataSlice(offset: 10, length: 20);
      final slice2 = DataSlice(offset: 10, length: 20);

      expect(slice1.offset, equals(slice2.offset));
      expect(slice1.length, equals(slice2.length));
    });
  });

  group('HashWithTree', () {
    test('combines hash with tree and queue public keys', () {
      final hash = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111112',
      );

      final hashWithTree = HashWithTree(hash: hash, tree: tree, queue: queue);

      expect(hashWithTree.hash, equals(hash));
      expect(hashWithTree.tree, equals(tree));
      expect(hashWithTree.queue, equals(queue));
    });

    test('converts to JSON correctly', () {
      final hash = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111112',
      );

      final hashWithTree = HashWithTree(hash: hash, tree: tree, queue: queue);
      final json = hashWithTree.toJson();

      expect(json['hash'], isNotNull);
      expect(json['tree'], equals('11111111111111111111111111111111'));
      expect(json['queue'], equals('11111111111111111111111111111112'));
    });
  });

  group('AddressWithTree', () {
    test('combines address with tree and queue public keys', () {
      final address = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111112',
      );

      final addressWithTree = AddressWithTree(
        address: address,
        tree: tree,
        queue: queue,
      );

      expect(addressWithTree.address, equals(address));
      expect(addressWithTree.tree, equals(tree));
      expect(addressWithTree.queue, equals(queue));
    });

    test('converts to JSON correctly', () {
      final address = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final queue = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111112',
      );

      final addressWithTree = AddressWithTree(
        address: address,
        tree: tree,
        queue: queue,
      );
      final json = addressWithTree.toJson();

      expect(json['address'], isNotNull);
      expect(json['tree'], equals('11111111111111111111111111111111'));
      expect(json['queue'], equals('11111111111111111111111111111112'));
    });
  });

  group('Paginated responses', () {
    test('WithCursor can chain multiple pages', () {
      // Simulate first page
      final page1 = WithCursor(items: [1, 2, 3], cursor: 'cursor-page-2');

      expect(page1.items.length, equals(3));
      expect(page1.cursor, isNotNull);

      // Simulate second page
      final page2 = WithCursor(items: [4, 5, 6], cursor: 'cursor-page-3');

      expect(page2.items.length, equals(3));

      // Simulate last page
      final page3 = WithCursor(items: [7, 8], cursor: null);

      expect(page3.items.length, equals(2));
      expect(page3.cursor, isNull); // No more pages
    });
  });

  group('Filter combinations', () {
    test('can combine multiple MemcmpFilters', () {
      final filter1 = MemcmpFilter(offset: 0, bytes: 'filter1');
      final filter2 = MemcmpFilter(offset: 32, bytes: 'filter2');

      final filters = [filter1, filter2];

      expect(filters.length, equals(2));
      expect(filters[0].offset, equals(0));
      expect(filters[1].offset, equals(32));
    });

    test('DataSlice can be used with filters', () {
      final filter = MemcmpFilter(offset: 0, bytes: 'owner-pubkey');
      final slice = DataSlice(offset: 0, length: 64);

      // In actual RPC calls, both would be used together
      expect(filter.offset, equals(0));
      expect(slice.offset, equals(0));
      expect(slice.length, equals(64));
    });
  });

  group('Complex response types', () {
    test('WithContext can wrap WithCursor', () {
      final items = [1, 2, 3];
      const cursor = 'next-page';
      final withCursor = WithCursor(items: items, cursor: cursor);

      final context = RpcContext(slot: 500);
      final response = WithContext(context: context, value: withCursor);

      expect(response.context.slot, equals(500));
      expect(response.value.items, equals(items));
      expect(response.value.cursor, equals(cursor));
    });

    test('can handle nested generics', () {
      final innerList = [
        ['a', 'b'],
        ['c', 'd'],
      ];
      final withCursor = WithCursor(items: innerList, cursor: null);

      expect(withCursor.items.length, equals(2));
      expect(withCursor.items[0].length, equals(2));
    });
  });

  group('HashWithTreeInfo', () {
    test('combines hash with full tree info', () {
      final hash = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final treeInfo = TreeInfo(
        tree: tree,
        queue: tree,
        treeType: TreeType.stateV1,
      );

      final hashWithTreeInfo = HashWithTreeInfo(
        hash: hash,
        stateTreeInfo: treeInfo,
      );

      expect(hashWithTreeInfo.hash, equals(hash));
      expect(hashWithTreeInfo.stateTreeInfo, equals(treeInfo));
      expect(hashWithTreeInfo.stateTreeInfo.treeType, equals(TreeType.stateV1));
    });
  });

  group('AddressWithTreeInfo', () {
    test('combines address with full tree info', () {
      final address = BN254.zero;
      final tree = Ed25519HDPublicKey.fromBase58(
        '11111111111111111111111111111111',
      );
      final treeInfo = TreeInfo(
        tree: tree,
        queue: tree,
        treeType: TreeType.addressV1,
      );

      final addressWithTreeInfo = AddressWithTreeInfo(
        address: address,
        addressTreeInfo: treeInfo,
      );

      expect(addressWithTreeInfo.address, equals(address));
      expect(addressWithTreeInfo.addressTreeInfo, equals(treeInfo));
      expect(
        addressWithTreeInfo.addressTreeInfo.treeType,
        equals(TreeType.addressV1),
      );
    });
  });
}
