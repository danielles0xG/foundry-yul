object "ERC1155"{
    code {
        sstore(0, caller())// Store owner in slot zero
        sstore(3,0x22) // length of uri 34
        sstore(add(3,1),0x68747470733A2F2F6F70656E7365612F7B69647D2E6A73) // hex of https://opensea/{id}.js
        sstore(add(3,2),0x6f6e000000000000000000000000000000000000000000000000000000000000)

        // Deploy
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        return(0, datasize("runtime"))
    }

    object "runtime" {
        code {
            require(iszero(callvalue())) // msg.value == 0

            function ownerSlot() -> p { p := 0 }
            function balanceSlot() -> p { p := 1 }
            function operatorApprovalSlot() -> p { p := 2 }
            function uriLengthSlot() -> p { p := 3 }  // URI (store length of string in this slot)

           
            switch selector() 
            case 0xf242432a { // safeTransferFrom(address,address,uint256,uint256,bytes)  
                require(eq(caller(),decodeAsAddress(0))) 
                require(iszero(isApprovedForAll(decodeAsAddress(0),decodeAsAddress(1))))

                transferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2))
                emitTransferSingle(
                    caller(),
                    decodeAsAddress(0),
                    decodeAsAddress(1),
                    decodeAsUint(2),
                    decodeAsUint(3)
                )
                require(gte(extcodesize(decodeAsAddress(1)),0))
                revertIfZeroAddress(decodeAsAddress(1))
                
                /**
                    CALL
                    Stack input
                        gas: amount of gas to send to the sub context to execute. The gas that is not used by the sub context is returned to this one.
                        address: the account which context to execute.
                        value: value in wei to send to the account.
                        argsOffset: byte offset in the memory in bytes, the calldata of the sub context.
                        argsSize: byte size to copy (size of the calldata).
                        retOffset: byte offset in the memory in bytes, where to store the return data of the sub context.
                        retSize: byte size to copy (size of the return data).
                */
                mstore(0x0,0xf23a6e61)
                mstore(0x20,caller())            // msg.sender
                mstore(0x40,decodeAsAddress(0))  // from
                mstore(0x60,decodeAsUint(2))     // id
                mstore(0x7c,decodeAsUint(3))     // amount
                mstore(0xa0,decodeAsUint(4))    // bytes
                // construct calldata of onERC1155Received(msg.sender, from, id, amount, data)
                require(eq(staticall(gas(), caller(), 0, 0, 0xa0, 0, 0),0)) // how to read msg bytes 0xf23a6e61 ?))
                returnTrue()
            }

            // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
            case 0x2eb2c2d6 {
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)
                let posIds := decodeAsUint(2)
                let posAmounts := decodeAsUint(3)
                require(or(eq(from, caller()), isApprovedForAll(from, caller())))
                let lenIds := decodeAsUint(div(posIds, 0x20))

                for { let i := 0 } lt(i, lenIds) { i:= add(i, 1) }
                {
                    let ithId := decodeAsUint(_getArrayElementSlot(posIds, i))
                    let ithAmount := decodeAsAddress(_getArrayElementSlot(posAmounts, i))
                    
                    transferFrom(from, to, ithId, ithAmount)
                }

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

            default {
                revert(0,0)
            }

            function transferFrom(from, to, amount) {
                executeTransfer(from, to, amount)
            }

            function executeTransfer(from, to, amount) {
                revertIfZeroAddress(to)
                deductFromBalance(from, amount)
                addToBalance(to, amount)
            }

            /* -------- storage layout ---------- */
            function ownerPos() -> p { p := 0 }
            function totalSupplyPos() -> p { p := 1 }
            function accountToStorageOffset(account) -> offset {
                offset := add(0x1000, account)
            }
            function approvallForAllStorageAccess(approver,approved) -> offset {
                offset := accountToStorageOffset(approver)
                mstore(0, offset)
                mstore(0x20, approved)
                offset := keccak256(0, 0x40)
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

            function addToBalance(account, amount) {
                let offset := accountToStorageOffset(account)
                sstore(offset, safeAdd(sload(offset), amount))
            }
            function deductFromBalance(account, amount) {
                let offset := accountToStorageOffset(account)
                let bal := sload(offset)
                require(lte(amount, bal))
                sstore(offset, sub(bal, amount))
            }

            //mapping(address => mapping(address => bool)) public isApprovedForAll;
            function isApprovedForAll(approver,approved) -> isApproved {
                isApproved := sload(approvallForAllStorageAccess(approver,approved))
            }

            function setApprovalForAll(operator,approved,isApproved){
                sstore(approvallForAllStorageAccess(operator,approved),isApproved)
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
                // 4bytes sig + 32bytes
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
            
            /* ---------- memroy pointers ---------- */
            function memPtrPos() -> p { p := 0x60 } // where is the memory pointer itself stored in memory
            function getMemPtr() -> p { p := mload(memPtrPos()) }
            function setMemPtr(v) { mstore(memPtrPos(), v) }
            function incrPtr() { mstore(memPtrPos(), safeAdd(getMemPtr(), 0x20)) } // ptr++


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

            function _getArrayElementSlot(posArr, i) -> calldataSlotOffset {
                // We're asking: how many 32-byte chunks into the calldata does this array's ith element lie
                // the array itself starts at posArra (starts meaning: that is where the pointer to the length of the array is stored)
                let startingOffset := div(safeAdd(posArr, 0x20), 0x20)
                calldataSlotOffset := safeAdd(startingOffset, i)
            }
        }
    }
}