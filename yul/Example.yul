object "Example" {
  code {
    datacopy(0, dataoffset("Runtime__"), datasize("Runtime__"))
    return(0, datasize("Runtime__"))
  }
  object "Runtime__" {
    // Return the calldata
    code {
      mstore(0x80, calldataload(0))
      return(0x80, calldatasize())
    }
  }
}