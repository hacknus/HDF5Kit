#if SWIFT_PACKAGE
import CHDF5
#endif

public protocol GroupType {
    var id: hid_t { get }
}

public class Group: Object, GroupType {
    /// Create a group
    public func createGroup(_ name: String) -> Group {
        let groupID = name.withCString {
            return H5Gcreate2(id, $0, 0, 0, 0)
        }
        return Group(id: groupID)
    }

    /// Open an existing group
    public func openGroup(_ name: String) -> Group? {
        let groupID = name.withCString {
            return H5Gopen2(id, $0, 0)
        }
        guard groupID >= 0 else {
            return nil
        }
        return Group(id: groupID)
    }

    public func open(_ name: String) -> Object {
        let oid = name.withCString { H5Oopen(id, $0, 0) }
        return Object(id: oid)
    }

    public func objectNames() -> [String] {
        var count: hsize_t = 0
        H5Gget_num_objs(id, &count)

        var names = [String]()
        names.reserveCapacity(Int(count))

        for i in 0..<count {
            let size = H5Gget_objname_by_idx(id, i, nil, 0)
            var name = [Int8](repeating: 0, count: size + 1)
            H5Gget_objname_by_idx(id, i, &name, size + 1)
            names.append(String(utf8String: name)!)
        }

        return names
    }

    public func datasetNames() -> [String] {
        var count: hsize_t = 0
        H5Gget_num_objs(id, &count)

        var datasetNames = [String]()

        for idx in 0..<count {
            let size = H5Gget_objname_by_idx(id, idx, nil, 0)
            var name = [Int8](repeating: 0, count: size + 1)
            H5Gget_objname_by_idx(id, idx, &name, size + 1)

            let objType = H5Iget_type(id)
            if objType == H5I_DATASET {
                datasetNames.append(String(utf8String: name)!)
            }
        }

        return datasetNames
    }

    public func attributeNames() -> [String] {
        var attributeNames = [String]()

        let count = H5Aget_num_attrs(id)
        guard count >= 0 else { return [] }

        for i in 0..<count {
            let attrID: hid_t = H5Aopen_by_idx(
                id,
                ".",
                H5_INDEX_NAME,
                H5_ITER_INC,
                hsize_t(i),
                hid_t(H5P_DEFAULT),
                hid_t(H5P_DEFAULT)
            )
            guard attrID >= 0 else { continue }

            var name = [Int8](repeating: 0, count: 256)
            let nameLen = H5Aget_name(attrID, 256, &name)
            if nameLen >= 0, let attributeName = String(validatingUTF8: name) {
                attributeNames.append(attributeName)
            }

            H5Aclose(attrID)
        }

        return attributeNames
    }
}
