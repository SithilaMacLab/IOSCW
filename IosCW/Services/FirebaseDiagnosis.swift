import Foundation

enum FirebaseDiagnosis {
    static var hasConfigFile: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static var hasAuthPackage: Bool {
        #if canImport(FirebaseAuth)
        true
        #else
        false
        #endif
    }

    static var hasFirestorePackage: Bool {
        #if canImport(FirebaseFirestore)
        true
        #else
        false
        #endif
    }

    static var problem: String? {
        if !hasAuthPackage && !hasFirestorePackage {
            return "The Firebase packages are not added to the IosCW target. Add FirebaseAuth and FirebaseFirestore in Xcode."
        }
        if !hasAuthPackage {
            return "FirebaseAuth is not added to the IosCW target, so sign-in only works on this phone."
        }
        if !hasFirestorePackage {
            return "FirebaseFirestore is not added to the IosCW target, so nothing is uploaded."
        }
        if !hasConfigFile {
            return "GoogleService-Info.plist is not inside the app. Put it in the IosCW folder and make sure the IosCW target is ticked for it."
        }
        return nil
    }
}
