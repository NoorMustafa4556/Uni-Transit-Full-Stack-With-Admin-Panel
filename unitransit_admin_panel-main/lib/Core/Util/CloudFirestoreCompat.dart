import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class Timestamp implements Comparable<Timestamp> {
  final DateTime dateTime;
  
  Timestamp(this.dateTime);
  
  factory Timestamp.fromDate(DateTime date) => Timestamp(date);
  
  factory Timestamp.now() => Timestamp(DateTime.now());
  
  DateTime toDate() => dateTime;

  static Timestamp fromMillisecondsSinceEpoch(int milliseconds) {
    return Timestamp(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }

  @override
  int compareTo(Timestamp other) => dateTime.compareTo(other.dateTime);

  @override
  String toString() => dateTime.toIso8601String();

  @override
  bool operator ==(Object other) => other is Timestamp && other.dateTime == dateTime;

  @override
  int get hashCode => dateTime.hashCode;
}

class FieldValue {
  static String serverTimestamp() => DateTime.now().toIso8601String();
}

class DocumentSnapshot {
  final String id;
  final Map<String, dynamic>? _data;
  
  DocumentSnapshot(this.id, this._data);
  
  Map<String, dynamic>? data() => _data;
  
  bool get exists => _data != null;
  
  DocumentReference get reference => DocumentReference('notifications', id);
}

class DocumentChange {
  final DocumentChangeType type;
  final DocumentSnapshot doc;
  DocumentChange(this.type, this.doc);
}

enum DocumentChangeType { added, modified, removed }

class QuerySnapshot {
  final List<DocumentSnapshot> docs;
  QuerySnapshot(this.docs);
  
  List<DocumentChange> get docChanges {
    return docs.map((doc) => DocumentChange(DocumentChangeType.added, doc)).toList();
  }
}

class DocumentReference {
  final String collectionPath;
  final String id;
  DocumentReference(this.collectionPath, this.id);

  CollectionReference collection(String subPath) {
    return CollectionReference('$collectionPath/$id/$subPath');
  }

  Future<DocumentSnapshot> get() async {
    final client = Supabase.instance.client;
    Map<String, dynamic>? data;

    if (collectionPath.contains('users') || collectionPath.contains('profiles') || collectionPath.contains('students')) {
      final res = await client.from('profiles').select().eq('id', id).maybeSingle();
      if (res != null) {
        data = _toCamelCase(res);
      }
    } else if (collectionPath.contains('drivers')) {
      final res = await client.from('drivers').select().eq('id', id).maybeSingle();
      if (res != null) {
        data = _toCamelCase(res);
      }
    } else if (collectionPath.contains('app_settings')) {
      final res = await client.from('app_settings').select().eq('key', id).maybeSingle();
      if (res != null) {
        data = _toCamelCase(res['value'] as Map<String, dynamic>);
      }
    }

    return DocumentSnapshot(id, data);
  }

  Future<void> update(Map<String, dynamic> data) async {
    final client = Supabase.instance.client;
    final snakeData = _toSnakeCase(data);

    if (collectionPath.contains('users') || collectionPath.contains('profiles') || collectionPath.contains('students')) {
      if (collectionPath.contains('notifications')) {
        await client.from('notifications').update(snakeData).eq('id', id);
      } else {
        await client.from('profiles').update(snakeData).eq('id', id);
      }
    } else if (collectionPath.contains('drivers')) {
      await client.from('drivers').update(snakeData).eq('id', id);
    } else if (collectionPath.contains('notifications')) {
      await client.from('notifications').update(snakeData).eq('id', id);
    } else if (collectionPath.contains('support_tickets')) {
      await client.from('support_tickets').update(snakeData).eq('id', id);
    }
  }

  Future<void> delete() async {
    final client = Supabase.instance.client;
    if (collectionPath.contains('notifications')) {
      await client.from('notifications').delete().eq('id', id);
    } else if (collectionPath.contains('support_tickets')) {
      await client.from('support_tickets').delete().eq('id', id);
    }
  }

  Stream<DocumentSnapshot> snapshots() {
    final client = Supabase.instance.client;
    final controller = StreamController<DocumentSnapshot>.broadcast();

    if (collectionPath.contains('drivers')) {
      if (id == null || id.isEmpty) {
        controller.add(DocumentSnapshot(id ?? '', null));
      } else {
        client.from('drivers').select().eq('id', id).asStream().listen((event) {
          if (event.isNotEmpty) {
            controller.add(DocumentSnapshot(id, _toCamelCase(event.first)));
          } else {
            controller.add(DocumentSnapshot(id, null));
          }
        });
      }
    } else if (collectionPath.contains('profiles') || collectionPath.contains('users') || collectionPath.contains('students')) {
      if (id == null || id.isEmpty) {
        controller.add(DocumentSnapshot(id ?? '', null));
      } else {
        client.from('profiles').select().eq('id', id).asStream().listen((event) {
          if (event.isNotEmpty) {
            controller.add(DocumentSnapshot(id, _toCamelCase(event.first)));
          } else {
            controller.add(DocumentSnapshot(id, null));
          }
        });
      }
    }

    return controller.stream;
  }
}

class CollectionReference extends Query {
  CollectionReference(super.collectionPath);

  DocumentReference doc([String? id]) {
    return DocumentReference(collectionPath, id ?? '');
  }

  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final client = Supabase.instance.client;
    final snakeData = _toSnakeCase(data);

    if (collectionPath.contains('sos_reviews')) {
      print("SOS Review logged to console: $snakeData");
    } else if (collectionPath.contains('notifications')) {
      await client.from('notifications').insert(snakeData);
    } else if (collectionPath.contains('support_tickets')) {
      await client.from('support_tickets').insert(snakeData);
    }
    return DocumentReference(collectionPath, '');
  }
}

class Query {
  final String collectionPath;
  
  Query(this.collectionPath);

  Query where(String field, {dynamic isEqualTo, dynamic whereIn, dynamic isGreaterThanOrEqualTo}) {
    return this;
  }

  Query orderBy(String field, {bool descending = false}) {
    return this;
  }

  Query limit(int value) {
    return this;
  }

  Query limitToLast(int value) {
    return this;
  }

  Future<QuerySnapshot> get() async {
    final client = Supabase.instance.client;
    List<Map<String, dynamic>> rows = [];

    if (collectionPath.contains('schedules')) {
      rows = await client.from('schedules').select();
    } else if (collectionPath.contains('users') || collectionPath.contains('profiles') || collectionPath.contains('students')) {
      if (collectionPath.contains('notifications')) {
        final uid = client.auth.currentUser?.id;
        rows = await client.from('notifications').select().eq('user_id', uid ?? '');
      } else {
        rows = await client.from('profiles').select();
      }
    } else if (collectionPath.contains('drivers')) {
      rows = await client.from('drivers').select();
    } else if (collectionPath.contains('notifications')) {
      final uid = client.auth.currentUser?.id;
      rows = await client.from('notifications').select().eq('user_id', uid ?? '');
    } else if (collectionPath.contains('support_tickets')) {
      final uid = client.auth.currentUser?.id;
      rows = await client.from('support_tickets').select().eq('user_id', uid ?? '');
    }

    final docs = rows.map((r) => DocumentSnapshot(r['id']?.toString() ?? '', _toCamelCase(r))).toList();
    return QuerySnapshot(docs);
  }

  Stream<QuerySnapshot> snapshots() {
    final client = Supabase.instance.client;
    final controller = StreamController<QuerySnapshot>.broadcast();

    if (collectionPath.contains('schedules')) {
      client.from('schedules').select().asStream().listen((event) {
        final docs = event.map((r) => DocumentSnapshot(r['id'].toString(), _toCamelCase(r))).toList();
        controller.add(QuerySnapshot(docs));
      });
    } else if (collectionPath.contains('notifications')) {
      final uid = client.auth.currentUser?.id;
      client.from('notifications').select().eq('user_id', uid ?? '').asStream().listen((event) {
        final docs = event.map((r) => DocumentSnapshot(r['id'].toString(), _toCamelCase(r))).toList();
        controller.add(QuerySnapshot(docs));
      });
    } else if (collectionPath.contains('support_tickets')) {
      final uid = client.auth.currentUser?.id;
      client.from('support_tickets').select().eq('user_id', uid ?? '').asStream().listen((event) {
        final docs = event.map((r) => DocumentSnapshot(r['id'].toString(), _toCamelCase(r))).toList();
        controller.add(QuerySnapshot(docs));
      });
    }

    return controller.stream;
  }
}

class FirebaseFirestore {
  static final FirebaseFirestore instance = FirebaseFirestore._();
  FirebaseFirestore._();

  CollectionReference collection(String path) => CollectionReference(path);
  
  WriteBatch batch() => WriteBatch();
}

class WriteBatch {
  final List<Future> _ops = [];

  void update(DocumentReference ref, Map<String, dynamic> data) {
    _ops.add(ref.update(data));
  }

  void delete(DocumentReference ref) {
    _ops.add(ref.delete());
  }

  Future<void> commit() async {
    await Future.wait(_ops);
  }
}

class FirebaseAuth {
  static final FirebaseAuth instance = FirebaseAuth._();
  FirebaseAuth._();

  FirebaseUser? get currentUser {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null ? FirebaseUser(user) : null;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Stream<FirebaseUser?> authStateChanges() {
    return Supabase.instance.client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? FirebaseUser(user) : null;
    });
  }
}

class FirebaseUser {
  final User _supabaseUser;
  FirebaseUser(this._supabaseUser);

  String get uid => _supabaseUser.id;
  String? get email => _supabaseUser.email;
  String? get displayName => _supabaseUser.userMetadata?['name'] as String?;
  String? get phoneNumber => _supabaseUser.phone;
}

class FirebaseStorage {
  static final FirebaseStorage instance = FirebaseStorage._();
  FirebaseStorage._();

  Reference ref() => Reference();
}

class Reference {
  final List<String> _paths = [];

  Reference child(String path) {
    _paths.add(path);
    return this;
  }

  Future<void> putFile(File file) async {
    final client = Supabase.instance.client;
    if (_paths.isEmpty) return;

    final bucket = _paths.first;
    final pathWithinBucket = _paths.sublist(1).join('/');
    
    await client.storage.from(bucket).upload(
      pathWithinBucket,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
  }

  Future<String> getDownloadURL() async {
    final client = Supabase.instance.client;
    if (_paths.isEmpty) return '';

    final bucket = _paths.first;
    final pathWithinBucket = _paths.sublist(1).join('/');
    
    return client.storage.from(bucket).getPublicUrl(pathWithinBucket);
  }
}

Map<String, dynamic> _toCamelCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final camelKey = key.replaceAllMapped(RegExp(r'_([a-z])'), (match) => match.group(1)!.toUpperCase());
    if (key == 'timestamp' || key == 'created_at' || key == 'resolved_at' || key == 'license_expiry') {
      if (value is String) {
        result[camelKey] = Timestamp(DateTime.parse(value));
      } else if (value is DateTime) {
        result[camelKey] = Timestamp(value);
      } else {
        result[camelKey] = value;
      }
    } else {
      result[camelKey] = value;
    }
  });
  return result;
}

Map<String, dynamic> _toSnakeCase(Map<String, dynamic> map) {
  final Map<String, dynamic> result = {};
  map.forEach((key, value) {
    final snakeKey = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
    if (value is Timestamp) {
      result[snakeKey] = value.toDate().toIso8601String();
    } else if (value is DateTime) {
      result[snakeKey] = value.toIso8601String();
    } else {
      result[snakeKey] = value;
    }
  });
  return result;
}
