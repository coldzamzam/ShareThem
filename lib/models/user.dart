import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  String username;
  String email;
  String? phoneNumber; 
  String? address;     
  String? photoUrl;    

  UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.phoneNumber,
    this.address,
    this.photoUrl, 
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String,
      username: data['username'] as String,
      email: data['email'] as String,
      phoneNumber: data['phoneNumber'] as String?, 
      address: data['address'] as String?,         
      photoUrl: data['photoUrl'] as String?,       
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'photoUrl': photoUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}