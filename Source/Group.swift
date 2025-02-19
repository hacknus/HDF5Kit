// Copyright © 2015 Venture Media Labs. All rights reserved.
//
// This file is part of HDF5Kit. The full HDF5Kit copyright notice, including
// terms governing use, modification, and redistribution, is contained in the
// file LICENSE at the root of the source code distribution tree.

#if SWIFT_PACKAGE
    import CHDF5
#endif

public protocol GroupType {
    var id: hid_t { get }
}

public class Group: Object, GroupType {
    /// Create a group
    public func createGroup(_ name: String) -> Group {
        let groupID = name.withCString{
            return H5Gcreate2(id, $0, 0, 0, 0)
        }
        return Group(id: groupID)
    }

    /// Open an existing group
    public func openGroup(_ name: String) -> Group? {
        let groupID = name.withCString{
            return H5Gopen2(id, $0, 0)
        }
        guard groupID >= 0 else {
            return nil
        }
        return Group(id: groupID)
    }

    /**
     Open an object in a group by path name.

     The object can be a group, dataset, or committed (named) datatype specified by a path name in an HDF5 file.

     - parameter name the path to the object relative to self
     */
    public func open(_ name: String) -> Object {
        let oid = name.withCString{ H5Oopen(id, $0, 0) }
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


    // Retrieve the names of all datasets in the group
    public func datasetNames() -> [String] {
        var count: hsize_t = 0
        H5Gget_num_objs(id, &count)

        var datasetNames = [String]()

        for idx in 0..<count {
            // Get the name of each object in the group
            let size = H5Gget_objname_by_idx(id, idx, nil, 0)
            var name = [Int8](repeating: 0, count: size + 1)
            H5Gget_objname_by_idx(id, idx, &name, size + 1)

            // Check if it's a dataset
            let objType = H5Iget_type(id)
            if objType == H5I_DATASET {
                datasetNames.append(String(utf8String: name)!)
            }
        }

        return datasetNames
    }

    // Retrieve the names of all attributes in the group
    public func attributeNames() -> [String] {
        // Get the number of attributes attached to this group
        var attributeNames = [String]()

        // Get the number of attributes
        let count = H5Aget_num_attrs(id)
        guard count >= 0 else { return [] }

        for i in 0..<count {
            // Open each attribute using the index
            let attrID: hid_t = -1
            let status = H5Aopen_by_idx(id, nil, H5_index_t(rawValue: i), H5_iter_order_t(rawValue: H5P_DEFAULT), hsize_t(attrID),0,0)
            guard status >= 0 else { continue }

            // Get the name of the attribute
            var name = [Int8](repeating: 0, count: 256)
            H5Aget_name(attrID, 256, &name)

            // Append the name to the list of attribute names
            if let attributeName = String(utf8String: name) {
                attributeNames.append(attributeName)
            }

            // Close the attribute after retrieving its name
            H5Aclose(attrID)
        }

        return attributeNames
    }
}
