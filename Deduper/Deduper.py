import hashlib
import sys
import time
import docstring

block_size = 32*1024

def hash_to_mem(file, print_progress=False):
    block_num = 0
    dict = {}
    list = []
    start_time = time.time()
    with open(file, "rb") as f:
        # Read first block
        block = f.read(block_size)
        while block != b"":
            # Computer SHA256 hash of read block
            hash_object = hashlib.sha256(block)
            hex_dig = hash_object.hexdigest()

            # Store the block hash to the dict (if unique) and also to the list of blocks (always)
            if not hex_dig in dict:
                dict[hex_dig] = block_num
            list.append(hex_dig)

            # Read next block
            block = f.read(block_size)

            block_num += 1

            # Print progress if enabled
            if print_progress and block_num % 1000 == 0:
                print('.', end='', flush=True)

    if print_progress:
        print("\nHashing speed: ", str(block_size * block_num / 1024 / (time.time() - start_time) / 1024), " MB/s")
    return {'dict': dict, 'list': list}


def hash_to_file(file_base, file_hash, print_progress=False):
    x = 0
    with open(file_base, "rb") as fb:
        with open(file_hash, "w") as fh:
            block = fb.read(block_size)
            while block != b"":
                hash_object = hashlib.sha256(block)
                hex_dig = hash_object.hexdigest()
                fh.write(hex_dig + "\n")

                block = fb.read(block_size)

                if print_progress:
                    x = (x + 1) % 1000
                    if x == 0:
                        print('.', end='', flush=True)


def hash_from_file(file_hash):
    dict = {}
    list = []
    with open(file_hash, "r") as fh:
        for cnt, line in enumerate(fh):
            if not line.strip() in dict:
                dict[line.strip()] = cnt
            list.append(line.strip())
    return {'dict': dict, 'list': list}

def deduplicate1(file_base, file_base_hashes, file_child, file_child_hashes, file_diff_ids, file_diff_data, print_progress=False):
    # Get block hashes of base file
    print('Hashing: base')
    hashes_base = hash_from_file(file_base_hashes)

    # Get block hashes of child file
    print('Hashing: child')
    hashes_child = hash_from_file(file_child_hashes)

    # Compare the base and child block hashes
    print('Comparing')
    base_dict = hashes_base['dict']
    blocks = [0, 0]
    with open(file_child, "rb") as fc:
        with open(file_diff_ids, "w") as fi:
            with open(file_diff_data, "wb") as fd:
                for hash in hashes_child['list']:
                    if hash in base_dict:
                        fi.write("B" + '{:04x}'.format(base_dict[hash]) + "\n")
                        blocks[0] += 1
                    else:
                        fi.write("C" + '{:04x}'.format(blocks[1]) + "\n")
                        fc.seek((blocks[0]+blocks[1]) * block_size)
                        block_data = fc.read(block_size)
                        fd.write(block_data)
                        blocks[1] += 1

    return blocks


def deduplicate2(file_base, file_child, file_diff_ids, file_diff_data, print_progress=False):
    # Hash blocks of base file
    if print_progress:
        print('Hashing: base...')
    hashes_base = hash_to_mem(file_base, print_progress)

    # Hash blocks of child file
    if print_progress:
        print('Hashing: child...')
    hashes_child = hash_to_mem(file_child, print_progress)

    # Compare the base and child block hashes
    if print_progress:
        print('Comparing...')
    base_dict = hashes_base['dict']
    blocks = [0, 0]
    just_base = True
    with open(file_child, "rb") as fc:
        with open(file_diff_ids, "w") as fi:
            with open(file_diff_data, "wb") as fd:
                for hash in hashes_child['list']:
                    if hash in base_dict:
                        fi.write("B" + '{:04x}'.format(base_dict[hash]) + "\n")
                        blocks[0] += 1
                    else:
                        fi.write("C" + '{:04x}'.format(blocks[1]) + "\n")
                        fc.seek((blocks[0]+blocks[1]) * block_size)
                        block_data = fc.read(block_size)
                        fd.write(block_data)
                        blocks[1] += 1
                        just_base = False
                    if print_progress and (blocks[0]+blocks[1]) % 1000 == 0:
                        if just_base:
                            print('.', end='', flush=True)
                        else:
                            print('#', end='', flush=True)
                        just_base = True
    if print_progress:
        print("")
    return blocks

def restore(file_base, file_child, file_diff_ids, file_diff_data, print_progress = False):
    start_time = time.time()
    with open(file_base, "rb") as fb:
        with open(file_child, "wb") as fc:
            with open(file_diff_ids, "r") as fi:
                with open(file_diff_data, "rb") as fd:
                    for block_num, line in enumerate(fi):
                        line = line.strip()
                        block_ptr = int(line[1:], 16)
                        if line[0] == "B":
                            fb.seek(block_ptr * block_size)
                            block_data = fb.read(block_size)
                        elif line[0] == "C":
                            fd.seek(block_ptr * block_size)
                            block_data = fd.read(block_size)
                        else:
                            print("Error! Unknown block type '", line[0], "'")
                            return
                        fc.write(block_data)

                        if print_progress and block_num % 1000 == 0:
                            print('.', end='', flush=True)
    if print_progress:
        print("\nRestoring speed: ", str(block_size * block_num / 1024 / (time.time() - start_time) / 1024), " MB/s")


####################################################################################################################
if __name__ == '__main__':

    g_start_time = time.time()

    # Help
    if len(sys.argv) == 1 and True == True:
        print("Syntax: Deduper.exe <command> [parameters]")
        print("Commands:")
        print("-h	--hash		<file_input> <file_hash_out>")
        print("-r	--restore	<file_base> <file_child_out> <file_diff_ids> <file_diff_data>")
        print("-d	--dedup		<file_base> <file_child> <file_diff_ids> <file_diff_data>")

    # Create hash (legacy)
    elif len(sys.argv) == 3 and (sys.argv[1] == "--hash" or sys.argv[1] == "-h"):
        file_base  = sys.argv[2]
        file_hash = sys.argv[3]
        hash_to_file(file_base, file_hash, True)

    # Restore
    elif len(sys.argv) == 6 and (sys.argv[1] == "--restore" or sys.argv[1] == "-r"):
        file_base			= sys.argv[2]
        file_child			= sys.argv[3]
        file_diff_ids		= sys.argv[4]
        file_diff_data		= sys.argv[5]

        restore(file_base, file_child, file_diff_ids, file_diff_data, True)

    # New deduplication
    elif len(sys.argv) == 6 and (sys.argv[1] == "--dedup" or sys.argv[1] == "-d"):
        file_base		= sys.argv[2]
        file_child		= sys.argv[3]
        file_diff_ids	= sys.argv[4]
        file_diff_data	= sys.argv[5]

        blocks = deduplicate2(file_base, file_child, file_diff_ids, file_diff_data, True)

        original_data_size = blocks[1] * block_size
        diff_file_size = ( (blocks[0] + blocks[1] * 5) + original_data_size )

        print("Block size:          ", str(int(block_size / 1024)), "KB")
        print("Original blocks:     ", str(blocks[1]))
        print("Deduplicated blocks: ", str(blocks[0]))
        print("Deduplication rate:  ", str(100*blocks[0]/(blocks[0]+blocks[1])), "%")
        print("Original data size:  ", str(original_data_size / 1024 / 1024), "MB")
        print("Diff file size:      ", str(diff_file_size / 1024 / 1024), "MB")

    # Legacy deduplication
    elif len(sys.argv) == 8 and (sys.argv[1] == "--dedup" or sys.argv[1] == "-d"):
        file_base = sys.argv[2]
        file_base_hashes = sys.argv[3]
        file_child = sys.argv[4]
        file_child_hashes = sys.argv[5]
        file_diff_ids = sys.argv[6]
        file_diff_data = sys.argv[7]

        blocks = deduplicate1(file_base, file_base_hashes, file_child, file_child_hashes, file_diff_ids, file_diff_data, True)

        original_data_size = blocks[1] * block_size
        diff_file_size = ( (blocks[0] + blocks[1] * 5) + original_data_size )

        print("Block size:          ", str(int(block_size / 1024)), "KB")
        print("Original blocks:     ", str(blocks[1]))
        print("Deduplicated blocks: ", str(blocks[0]))
        print("Deduplication rate:  ", str(100*blocks[0]/(blocks[0]+blocks[1])), "%")
        print("Original data size:  ", str(original_data_size / 1024 / 1024), "MB")
        print("Diff file size:      ", str(diff_file_size / 1024 / 1024), "MB")

    else:
        print("Error")

    print("\nDone in ", time.time() - g_start_time, " second(s)")
