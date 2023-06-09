object "ERC1155"{
    code {
        // Store owner in slot zero
        sstore(0, caller())

        // Deploy
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }

    object "runtime" {
        code {
            require(iszero(callvalue())) // msg.value == 0
           
            switch selector() 
            // safeTransferFrom(address,address,uint256,uint256,bytes)  
            case 0xf242432a {

            }

            // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
            case 0x2eb2c2d6 {

            }

            case 0x70a08231 { // balanceOf(address)  
                returnUint(balanceOf(decodeAsAddress(0)))
            }

            case 0x4e1273f4 { // balanceOfBatch(address[],uint256[])  

            }

            case 0xa22cb465 { // setApprovalForAll(address,bool)  

            }

            case 0x0e89341c { // uri(uint256) 

            }

            case 0xe985e9c5 { // isApprovedForAll(address,address)  

            }

            /* -------- storage access ---------- */

            function owner() -> o {
                o := sload(ownerPos())
            }

            function totalSupply() -> supply {
                supply := sload(totalSupplyPos())
            }

            function balanceOf(account) -> bal {
                bal := sload(accountToStorageOffset(account))
            }

            /* -------- storage layout ---------- */
            function ownerPos() -> p { p := 0 }
            function totalSupplyPos() -> p { p := 1 }
            function accountToStorageOffset(account) -> offset {
                offset := add(0x1000, account)
            }


            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
            }

            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }
            
            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }
            /* ---------- calldata encoding functions ---------- */

            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }
            function returnTrue() {
                returnUint(1)
            }

            /* -------- events ---------- */

            function emitTransferSingle(operator,from,to,id,amount) {
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
                emitTransferEvent(signatureHash,operator,from,to,id,amount)
            }

            function emitTransferBatch(operator,from,to,ids,amounts) {
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
                emitTransferEvent(signatureHash,operator,from,to,ids,amounts)
            }

            function emitTransferEvent(signatureHash,indexed1,indexed2,indexed3,ids,amounts){
                mstore(0x00,ids)
                mstore(0x20,amounts)
                log4(0,0x20,signatureHash,indexed1,indexed2,indexed3)
            }

            function emitApprovalForAll(_owner,operator,approved) {
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
                emitEvent(signatureHash,_owner,operator,approved)
            }

            function emitURI(value, id){
                let signatureHash := 0x1e7006e7e1807813182bd046558f9f54c45ada88a99785110f4ac900ae6a704d
                emitEvent(signatureHash,value,id,0x0)
            }

            function emitEvent(signatureHash, indexed1, indexed2, nonIndexed) {
                mstore(0, nonIndexed)
                log3(0, 0x20, signatureHash,indexed1,indexed2)
            }

            /* ---------- utility functions ---------- */
            function lte(a, b) -> r {
                r := iszero(gt(a, b))
            }
            function gte(a, b) -> r {
                r := iszero(lt(a, b))
            }
            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }
            function calledByOwner() -> cbo {
                cbo := eq(owner(), caller())
            }
            function revertIfZeroAddress(addr) {
                require(addr)
            }
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
        }
    }
}