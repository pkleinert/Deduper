import hashlib
import sys
import time
from pathlib import Path
#import docstring

# Threading
import os
import psutil

ext_hashes=".dh1"

block_size = 64*1024

import threading
import time

class StoppableThread(threading.Thread):
    def __init__(self):
        super(StoppableThread, self).__init__()
        self.daemon = True
        self.__monitor = threading.Event()
        self.__monitor.set()
        self.__has_shutdown = False

    def run(self):
        '''Overloads the threading.Thread.run'''
        # Call the User's Startup functions
        self.startup()

        # Loop until the thread is stopped
        while self.isRunning():
            self.mainloop()

        # Clean up
        self.cleanup()

        # Flag to the outside world that the thread has exited AND that the cleanup is complete
        self.__has_shutdown = True

    def stop(self):
        self.__monitor.clear()

    def isRunning(self):
        return self.__monitor.isSet()

    def isShutdown(self):
        return self.__has_shutdown


class MemUsageSniffingClass(StoppableThread):
    def __init__(self, refresh_time):
        super(MemUsageSniffingClass, self).__init__()
        self.max_mem = 0
        self.refresh_time = refresh_time

    def startup(self):
        # Overload the startup function
        pass

    def cleanup(self):
        # Overload the cleanup function
        pass

    def mainloop(self):
        curr_mem = psutil.Process(os.getpid()).memory_info().rss
        if curr_mem > self.max_mem:
            self.max_mem = curr_mem
        time.sleep(self.refresh_time)


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
        print()
    print(" Hashing speed: %8.3f MB/s" % (block_size * block_num / 1024 / (time.time() - start_time + 0.1) / 1024) )
    print(" Hashing took:  %d:%02d" % divmod(time.time() - start_time, 60) )
    return {'dict': dict, 'list': list}


def write_hashes_to_file(hashes, file_hash):
    with open(file_hash, "w") as fh:
        for hash in hashes['list']:
            fh.write(hash + "\n")


def hash_from_file(file_hash):
    dict = {}
    list = []
    with open(file_hash, "r") as fh:
        for cnt, line in enumerate(fh):
            if not line.strip() in dict:
                dict[line.strip()] = cnt
            list.append(line.strip())
    return {'dict': dict, 'list': list}


def deduplicate(file_base, file_child, file_diffs, print_progress=False):
    # Hash blocks of base file
    file_indexes_base = file_base + ext_hashes
    if Path(file_indexes_base).is_file() and Path(file_base).stat().st_mtime <= Path(file_indexes_base).stat().st_mtime:
        print('Base: reading from', file_indexes_base)
        hashes_base = hash_from_file(file_indexes_base)
    else:
        print('Base: hashing', file_base)
        hashes_base = hash_to_mem(file_base, print_progress)
        write_hashes_to_file(hashes_base, file_indexes_base)

    # Hash blocks of child file
    file_indexes_child = file_child + ext_hashes
    if Path(file_indexes_child).is_file()  and Path(file_child).stat().st_mtime <= Path(file_indexes_child).stat().st_mtime:
        print('Child: reading from', file_indexes_child)
        hashes_child = hash_from_file(file_indexes_child)
    else:
        print('Child: hashing', file_child)
        hashes_child = hash_to_mem(file_child, print_progress)
        write_hashes_to_file(hashes_child, file_child + ext_hashes)

    # Compare the base and child block hashes
    start_time = time.time()
    base_dict = hashes_base['dict']
    blocks = [0, 0]
    just_base = True
    with open(file_child, "rb") as fc:
        with open(file_diffs, "wb") as fd:
			# Make room for the indexes and the index end marker
            print("Comparing", len(hashes_child['list']), "indexes")
            fd.seek(( len(hashes_child['list']) + 1) * (1 + 8 + 2))
            indexes = ""

			# Start finding and outputting original blocks
            for hash in hashes_child['list']:
                if hash in base_dict:
                    indexes += "B" + '{:08x}'.format(base_dict[hash]) + "\r\n"
                    blocks[0] += 1
                else:
                    indexes += "C" + '{:08x}'.format(blocks[1]) + "\r\n"
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

            # Write indexes and end marker to the beginning of the file
            indexes += "Effffffff\r\n"
            fd.seek(0)
            fd.write(indexes.encode('ascii'))

    if print_progress:
        print("")
    print(" Deduplication speed: %8.3f MB/s" % (block_size * (blocks[0]+blocks[1]) / 1024 / (time.time() - start_time + 0.1) / 1024) )
    print(" Deduplication took:  %d:%02d" % divmod(time.time() - start_time, 60) )

    return blocks

def restore(file_base, file_child, file_diffs, print_progress = False):
    start_time = time.time()
    with open(file_base, "rb") as fb:
        with open(file_child, "wb") as fc:
            with open(file_diffs, "rb") as fd:
                print("Reading: indexes")
                lines = []
                while True:
                    line = fd.read(1 + 8 + 2)
                    line = line.decode().strip()
                    if line == "Effffffff":
                        break;
                    lines.append(line)

                data_begin_pos = fd.tell()
                print("Combining base and diffs to the output")
                block_num = 0
                for line in lines:
                    block_num += 1
                    block_ptr = int(line[1:], 16)
                    if line[0] == "B":
                        fb.seek(block_ptr * block_size)
                        block_data = fb.read(block_size)
                    elif line[0] == "C":
                        fd.seek(data_begin_pos + block_ptr * block_size)
                        block_data = fd.read(block_size)
                    else:
                        print("Error! Unknown block type '", line[0], "'")
                        return
                    fc.write(block_data)

                    if print_progress and block_num % 1000 == 0:
                        print('.', end='', flush=True)

    if print_progress:
        print("")
    print(" Restore speed: ", str(block_size * block_num / 1024 / (time.time() - start_time) / 1024 + 0.1), " MB/s")
    print(" Restore took:  %d:%02d" % divmod(time.time() - start_time, 60) )


####################################################################################################################
if __name__ == '__main__':

    g_start_time = time.time()

    # Enable RSS process memory monitoring each 1 second
    mem_usage_thread = MemUsageSniffingClass(1)
    mem_usage_thread.start()

    # Help
    if len(sys.argv) == 1 and True == True:
        print("Syntax: Deduper.exe <command> [parameters]")
        print("Commands:")
        print("-h --hash    <file_input>   [file_hash_out]")
        print("-r --restore <file_base_in> <file_child_out> <file_diffs_in>")
        print("-d --dedup   <file_base_in> <file_child_in> <file_diffs_out>")
        print("Alternativeny -sd or --silent-dedup to skip printing the progress")
        print("Note: Block size:", block_size)

    # Create hash
    elif (len(sys.argv) == 3 or len(sys.argv) == 4) and (sys.argv[1] == "--hash" or sys.argv[1] == "-h"):
        file_base  = sys.argv[2]
        if len(sys.argv) == 4:
            file_hash = sys.argv[3]
        else:
            file_hash = file_base + ext_hashes

        hashes_child = hash_to_mem(file_child, True)
        write_hashes_to_file(hashes_child, file_hash)

    # Restore
    elif len(sys.argv) == 5 and (sys.argv[1] == "--restore" or sys.argv[1] == "-r"):
        file_base			= sys.argv[2]
        file_child			= sys.argv[3]
        file_diffs  		= sys.argv[4]

        restore(file_base, file_child, file_diffs, True)

    # Deduplication
    elif len(sys.argv) == 5 and (sys.argv[1] == "--dedup" or sys.argv[1] == "-d" or sys.argv[1] == "--silent-dedup" or sys.argv[1] == "-sd"):
        file_base		= sys.argv[2]
        file_child		= sys.argv[3]
        file_diffs  	= sys.argv[4]

        blocks = deduplicate(file_base, file_child, file_diffs, sys.argv[1] == "--dedup" or sys.argv[1] == "-d")

        original_data_size = blocks[1] * block_size
        diff_file_size = ( (blocks[0] + blocks[1] * 5) + original_data_size )

        print(" Block size:          %8.3f KB" % (block_size / 1024) )
        print(" Unique blocks:       %8i" % (blocks[1]) )
        print(" Deduplicated blocks: %8i" % (blocks[0]) )
        print(" Deduplication rate:  %8.3f %%" % (100*blocks[0]/(blocks[0]+blocks[1])) )
        print(" Child file size:   %10.3f MB" % (Path(file_child).stat().st_size / 1024 / 1024) )
        print(" Unique data size:  %10.3f MB" % (original_data_size / 1024 / 1024) )
        print(" Diff file size:    %10.3f MB" % (diff_file_size / 1024 / 1024) )
    else:
        print("Error")

    print("Done in %d:%02d" % divmod(time.time() - g_start_time, 60), end='' )
    print("; maximum RAM usage %.0f MB" % (mem_usage_thread.max_mem / 1024 / 1024))
