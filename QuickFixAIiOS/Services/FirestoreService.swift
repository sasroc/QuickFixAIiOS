import Foundation
import FirebaseFirestore

// Make Firestore.Timestamp conform to the protocol defined in User.swift
extension Timestamp: @retroactive FirestoreTimestampProtocol {}

// MARK: - Firestore helpers

extension Firestore {
    static var db: Firestore { Firestore.firestore() }
}
