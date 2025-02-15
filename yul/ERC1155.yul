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
            case 0x0febdd49 /* function safeTransferFrom(address from, address to, uint256 id, uint256 amount) */ {

                let from := decodeAsAddress(0)
                // check that msg.sender is allowed to transfer `from`'s tokens
                // (which they are if msg.sender == from of course)
                require(or(eq(from, caller()), _isApprovedForAll(from, caller())))

                let to := decodeAsAddress(1)
                require(gte(extcodesize(to),0))
                revertIfZeroAddress(to)

                let id := decodeAsUint(2)
                let amount := decodeAsUint(3)

                _safeTransferFrom(from, to, id, amount)

                /**
                    STATICALL Stack input
                        gas: amount of gas to send to the sub context to execute. The gas that is not used by the sub context is returned to this one.
                        address: the account which context to execute.
                        argsOffset: byte offset in the memory in bytes, the calldata of the sub context.
                        argsSize: byte size to copy (size of the calldata).
                        retOffset: byte offset in the memory in bytes, where to store the return data of the sub context.
                        retSize: byte size to copy (size of the return data).
                */
                let interface := 0xf23a6e61
                mstore(getMemPtr(),interface) 
                // construct calldata of onERC1155Received(msg.sender, from, id, amount, data)
                let success := staticcall(gas(), to, getMemPtr(), 0x100, 0x00, 0x20)
                require(success)
                // read the reponse like a function signature
                let response := decodeAsSelector(mload(0x00))
                let requiredInterface := decodeAsSelector(interface)
                require(eq(response, requiredInterface))
                
                emitTransferSingle(
                    caller(),
                    decodeAsAddress(0),
                    decodeAsAddress(1),
                    decodeAsUint(2),
                    decodeAsUint(3)
                )
                returnTrue()
            }

            case 0xfba0ee64 /* function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts) */ {
                let from := decodeAsAddress(0)
                // are we allowed to transfer
                require(or(eq(from, caller()), _isApprovedForAll(from, caller())))

                let to := decodeAsAddress(1)
                let posIds := decodeAsUint(2)
                let posAmounts := decodeAsUint(3)

                let lenIds := decodeAsUint(div(posIds, 0x20))

                // then add the balance of each (account, id) requested up to `lenAccounts`
                for { let i := 0 } lt(i, lenIds) { i:= add(i, 1) }
                {
                    let ithId := decodeAsUint(_getArrayElementSlot(posIds, i))
                    let ithAmount := decodeAsAddress(_getArrayElementSlot(posAmounts, i))
                    
                    _safeTransferFrom(from, to, ithId, ithAmount)
                }


                emitTransferBatch(caller(), from, to, posIds, posAmounts)

                returnNothing()
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

            function returnNothing(){
                return(0,0)
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

            function _safeTransferFrom(from, to, id, amount) {
                let fromSlot := _getBalanceSlot(from, id)
                let toSlot := _getBalanceSlot(to, id)
                
                // from = from - amount
                let fromOld := sload(fromSlot)
                let fromNew := safeSub(fromOld, amount)
                sstore(fromSlot, fromNew)

                // to = to + amount
                let toOld := sload(toSlot)
                let toNew := safeAdd(toOld, amount)
                sstore(toSlot, toNew)
            }

            function _getBalanceSlot(_address, id) -> slot {
                // key = <balanceSlot><to><id>
                // slot = keccak256(key)
                mstore(0x00, balanceSlot()) // use scratch space for hashing
                mstore(0x20, _address)
                mstore(0x40, id)
                slot := keccak256(0x00, 0x60)
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
            function safeSub(a, b) -> r {
                r := sub(a, b)
                if gt(r, a) { revert(0, 0) }
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

            function decodeAsSelector(value) -> sel {
                sel := div(value, 0x100000000000000000000000000000000000000000000000000000000)
            }

            function _isApprovedForAll(account, operator) -> approved {
                approved := sload(_getOperatorApprovalSlot(account, operator))
            }

            function _getArrayElementSlot(posArr, i) -> calldataSlotOffset {
                // We're asking: how many 32-byte chunks into the calldata does this array's ith element lie
                // the array itself at posArra (starts meaning: that is where the pointer to the length of the array is stored)
                let startingOffset := div(safeAdd(posArr, 0x20), 0x20)
                calldataSlotOffset := safeAdd(startingOffset, i)
            }

            /// @dev retrieve the storage slot where approval information is stored
            /// @dev mapping(address => mapping(address => bool)) private _operatorApprovals;
            function _getOperatorApprovalSlot(account, operator) -> slot {
                // key = <operatorApprovalSlot><owner><operator>
                // slot = keccak256(key)
                mstore(0x00, operatorApprovalSlot())
                mstore(0x20, account)
                mstore(0x40, operator)
                slot := keccak256(0x00, 0x60)
            }

        }
    }
}