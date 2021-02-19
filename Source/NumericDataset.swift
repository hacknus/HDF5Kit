//
//  File 2.swift
//  
//
//  Created by Jeffrey Barahona on 2/18/21.
//

#if SWIFT_PACKAGE
    import CHDF5
#endif
public protocol NativeDataset {}
public class NumericDataset<T:NumericType>: Dataset, NativeDataset {
    public subscript(slices: HyperslabIndexType...) -> [T] {
        // There is a problem with Swift where it gives a compiler error if `set` is implemented here
        return (try? read(slices)) ?? []
    }

    public subscript(slices: [HyperslabIndexType]) -> [T] {
        get {
            return (try? read(slices)) ?? []
        }
        set {
            try! write(newValue, to: slices)
        }
    }

    public func read(_ slices: [HyperslabIndexType]) throws -> [T] {
        let filespace = space
        filespace.select(slices)
        return try read(memSpace: Dataspace(dims: filespace.selectionDims), fileSpace: filespace)
   }

    public func write(_ data: [T], to slices: [HyperslabIndexType]) throws {
        let filespace = space
        filespace.select(slices)
        try write(data, memSpace: Dataspace(dims: filespace.selectionDims), fileSpace: filespace)
    }

    /// Append data to the table
    public func append(_ data: [T], dimensions: [Int], axis: Int = 0) throws {
        let oldExtent = extent
        extent[axis] += dimensions[axis]
        for (index, dim) in dimensions.enumerated() {
            if dim > oldExtent[index] {
                extent[index] = dim
            }
        }

        var start = [Int](repeating: 0, count: oldExtent.count)
        start[axis] = oldExtent[axis]

        let fileSpace = space
        fileSpace.select(start: start, stride: nil, count: dimensions, block: nil)

        try write(data, memSpace: Dataspace(dims: dimensions), fileSpace: fileSpace)
    }

    /// Read data using an optional memory Dataspace and an optional file Dataspace
    ///
    /// - precondition: The `selectionSize` of the memory Dataspace is the same as for the file Dataspace
    public func read(memSpace: Dataspace? = nil, fileSpace: Dataspace? = nil) throws -> [T] {
        let size: Int
        if let memspace = memSpace {
            size = memspace.size
        } else if let filespace = fileSpace {
            size = filespace.selectionSize
        } else {
            size = space.selectionSize
        }

        var result = [T](repeating: 0 as! T , count: size)
        try result.withUnsafeMutableBufferPointer() { (pointer: inout UnsafeMutableBufferPointer) in
            try read(into: pointer.baseAddress!, memSpace: memSpace, fileSpace: fileSpace)
        }
        return result
    }

    /// Read data using an optional memory Dataspace and an optional file Dataspace
    ///
    /// - precondition: The `selectionSize` of the memory Dataspace is the same as for the file Dataspace and there is enough memory available for it
    public func read(into pointer: UnsafeMutablePointer<T>, memSpace: Dataspace? = nil, fileSpace: Dataspace? = nil) throws {
        try super.read(into: pointer, type: .float, memSpace: memSpace, fileSpace: fileSpace)
    }

    /// Write data using an optional memory Dataspace and an optional file Dataspace
    ///
    /// - precondition: The `selectionSize` of the memory Dataspace is the same as for the file Dataspace and the same as `data.count`
    public func write(_ data: [T], memSpace: Dataspace? = nil, fileSpace: Dataspace? = nil) throws {
        let size: Int
        if let memspace = memSpace {
            size = memspace.size
        } else if let filespace = fileSpace {
            size = filespace.selectionSize
        } else {
            size = space.selectionSize
        }
        precondition(data.count == size, "Data size doesn't match Dataspace dimensions")

        try data.withUnsafeBufferPointer() { bufferPointer in
            try write(from: bufferPointer.baseAddress!, memSpace: memSpace, fileSpace: fileSpace)
        }
    }

    /// Write data using an optional memory Dataspace and an optional file Dataspace
    ///
    /// - precondition: The `selectionSize` of the memory Dataspace is the same as for the file Dataspace
    public func write(from pointer: UnsafePointer<T>, memSpace: Dataspace? = nil, fileSpace: Dataspace? = nil) throws {
        try super.write(from: pointer, type: .float, memSpace: memSpace, fileSpace: fileSpace)
    }
}


// MARK: GroupType extension for TDataset

extension GroupType {
    /// Create a TDataset
    public func createNumericDataset<T:NumericType>(_ name: String, dataspace: Dataspace, type:T.Type) -> NumericDataset<T>? {
        guard let datatype = Datatype(type: type.self) else {
            return nil
        }
        let datasetID = name.withCString { name in
            return H5Dcreate2(id, name, datatype.id, dataspace.id, 0, 0, 0)
        }
        return NumericDataset(id: datasetID)
    }

    /// Create a chunked NumericDataset
    public func createNumericDataset<T:NumericType>(_ name: String, dataspace: Dataspace, chunkDimensions: [Int], type:T.Type) -> NumericDataset<T>? {
        guard let datatype = Datatype(type: type.self) else {
            return nil
        }
        precondition(dataspace.dims.count == chunkDimensions.count)

        let plist = H5Pcreate(H5P_CLS_DATASET_CREATE_ID_g)
        H5Pset_char_encoding(plist, H5T_CSET_UTF8)
        let chunkDimensions64 = chunkDimensions.map({ hsize_t(bitPattern: hssize_t($0)) })
        chunkDimensions64.withUnsafeBufferPointer { (pointer) -> Void in
            H5Pset_chunk(plist, Int32(chunkDimensions.count), pointer.baseAddress)
        }
        defer {
            H5Pclose(plist)
        }

        let datasetID = name.withCString{ name in
            return H5Dcreate2(id, name, datatype.id, dataspace.id, 0, plist, 0)
        }
        return NumericDataset(id: datasetID)
    }

    /// Create a Numeric Dataset and write data
    public func createAndWriteDataset<T:NumericType>(_ name: String, dims: [Int], data: [T], type:T.Type) throws -> NumericDataset<T> {
        let space = Dataspace.init(dims: dims)
        let set = createNumericDataset(name, dataspace: space, type:type)!
        try set.write(data)
        return set
    }

    /// Open an existing NumericDataset
    public func openNumericDataset<T:NumericType>(_ name: String, type:T.Type) -> NumericDataset<T>? {
        let datasetID = name.withCString{ name in
            return H5Dopen2(id, name, 0)
        }
        guard datasetID >= 0 else {
            return nil
        }
        return NumericDataset<T>(id: datasetID)
    }
}
