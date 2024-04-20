import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class FirestoreService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<FirestoreService> init() async {
    // Perform initialization if necessary
    return this;
  }

  // Get all documents from a collection
  Future<List<Map<String, dynamic>>> getAllDocuments(
      String collectionPath) async {
    var querySnapshot = await _db.collection(collectionPath).get();
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get a single document by ID
  Future<Map<String, dynamic>?> getDocumentById(
      String collectionPath, String docId) async {
    var documentSnapshot =
        await _db.collection(collectionPath).doc(docId).get();
    return documentSnapshot.data();
  }

  // Add a new document
  Future<void> addDocument(
      String collectionPath, Map<String, dynamic> newData) async {
    await _db.collection(collectionPath).add(newData);
  }

  // Update an existing document
  Future<void> updateDocument(String collectionPath, String docId,
      Map<String, dynamic> updatedData) async {
    await _db.collection(collectionPath).doc(docId).update(updatedData);
  }

  // Delete a document
  Future<void> deleteDocument(String collectionPath, String docId) async {
    await _db.collection(collectionPath).doc(docId).delete();
  }
}
