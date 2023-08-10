%builtins output range_check

from starkware.cairo.common.alloc import alloc


func prepare() ->felt{
%{
import json
import subprocess
from collections import defaultdict
import glob
import os

def get_status_data(file):
    with open(file, 'r') as f:
        status_data = json.load(f)
    return status_data['Data']

def compute_diff(status1, status2):
    diff = defaultdict(int)
    for status in status1:
        diff[status['address']] -= status['amount']
    for status in status2:
        diff[status['address']] += status['amount']
    return diff

def get_transactions_data(file):
    with open(file, 'r') as f:
        transactions_data = json.load(f)
    return transactions_data['transactions']

def verify_signatures(file):
    transactions = get_transactions_data(file)
    valid = defaultdict(int)
    for tx in transactions:
        method = tx['method']
        senderAddress = tx['sAddr']
        receiptAddress = tx['rAddr']
        amount = tx['amt']
        tick = tx['tick']
        signature = tx['sig']
        message = json.dumps({
            "method": method,
            "sAddr": senderAddress,
            "rAddr": receiptAddress,
            "amt": amount,
            "tick": tick,
            "sig": ""
        }, separators=(',', ':'))
        process = subprocess.run(['node', './bisonappbackend_nodejs/bip322Verify.js', senderAddress, message, signature], text=True, capture_output=True)
        result = process.stdout.strip() 
        #print(result)
        if result == 'true':
            valid[tx['sAddr']] -= int(amount)
            valid[tx['rAddr']] += int(amount)
    return valid
    
def write_json(diff1, diff2, all_addresses):
    data = {
        "status_change_list": [diff1.get(addr, 0) for addr in all_addresses],
        "transaction_change_list": [diff2.get(addr, 0) for addr in all_addresses]
    }
    with open('zk_tmp.json', 'w') as f:
        json.dump(data, f)

def main():
    status_files = sorted(glob.glob('./status/*.json'), key=os.path.getmtime)
    proof_files = sorted(glob.glob('./statusProof/*.json'), key=os.path.getmtime)
    latest_status_file = status_files[-1]
    previous_status_file = status_files[-2]
    latest_proof_file = proof_files[-1]

    status1_data = get_status_data(previous_status_file)
    status2_data = get_status_data(latest_status_file)
    all_addresses = {tx['address'] for tx in status1_data + status2_data}

    status_diff = compute_diff(status1_data, status2_data)
    tx_diff = verify_signatures(latest_proof_file)

    #print_balances(status_diff, "Status balances changes:")
    #print_balances(tx_diff, "Transaction balance changes:")
    write_json(status_diff, tx_diff, all_addresses)

main()
%}
    return 0;
}

func check_solution(loc_list: felt*,tile_list: felt*, n_steps) -> felt {
    if (n_steps == 0) {
        return 0;
    }

    // size is not zero.
    assert loc_list[0] = tile_list[0];


    let res = check_solution(loc_list=loc_list + 1, tile_list=tile_list + 1,n_steps=n_steps - 1);
    return res;
}

func main{output_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    prepare();

    // Declare two variables that will point to the two lists and
    // another variable that will contain the number of steps.
    local loc_list: felt*;
    local tile_list: felt*;
    local n_steps;

    %{
        # The verifier doesn't care where those lists are
        # allocated or what values they contain, so we use a hint
        # to populate them.
        locations = program_input['status_change_list']
        tiles = program_input['transaction_change_list']

        ids.loc_list = loc_list = segments.add()
        for i, val in enumerate(locations):
            memory[loc_list + i] = val

        ids.tile_list = tile_list = segments.add()
        for i, val in enumerate(tiles):
            memory[tile_list + i] = val

        ids.n_steps = len(tiles)
        print(tiles)

        # Sanity check (only the prover runs this check).
        assert len(locations) == len(tiles)
    %}


    check_solution(
        loc_list=loc_list, tile_list=tile_list, n_steps=n_steps
    );
    %{   
        print("Status Prove Succeeded!")
    %}

    return ();
}