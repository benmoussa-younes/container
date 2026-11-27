# subid-plan.awk — decide what /etc/subuid and /etc/subgid must say for one
# account, so the role never writes a range it has not checked.
#
# The target host has no Scripts interpreter (the collection installs on a host
# it does not own), so this helper is POSIX awk: `awk -f` on Debian's mawk.
#
# Usage:
#   awk -f subid-plan.awk -v user=alice -v base=100000 -v count=65536 \
#       -v uidfile=/etc/subuid -v gidfile=/etc/subgid \
#       -v passwdfile=/etc/passwd -v groupfile=/etc/group \
#       /etc/subuid /etc/subgid /etc/passwd /etc/group
#
# Output: one status line first. `OK` ends there; `BADARG` and `BADLINE` refuse
# the invocation; every other answer adds zero or more `REMOVE` lines, then
# exactly one `PLAN <start> <count>` or `NOFREE`. Exit status is 0 whenever the
# files were readable; the caller decides what a status means.
#
#   OK <start> <count>                one usable range in both files
#   ADD <start> <count>               absent from both, <start> is a free block
#   CONFLICT <start> <count> <other>  the account's range overlaps <other>
#   SMALL <start> <count>             the account's range is shorter than count
#   MISMATCH <uid> <gid>              the two files disagree on start or length
#   HALF uid|gid                      the account is in one file only
#   MULTI uid|gid <n>                 the account has more than one range in a file
#   BADARG name|count|base            the invocation cannot produce a safe block
#   BADLINE uid|gid <line text>       a line is not `name:start:count`
#
#   REMOVE uid|gid <start> <count>    a range the repair deletes before it adds
#   PLAN <start> <count>              the block a change adds
#   NOFREE                            no aligned block is free below 2^32
#
# A range is usable when it is present in both files, has exactly one line per
# file, is at least `count` long, starts at the same value in both files with the
# same length, and overlaps no other account's range in that same file.
#
# The invocation is refused rather than trusted: a count below one or above
# MAX_COUNT, a base below 100000 (Debian's SUB_UID_MIN) or a name that cannot be
# written to the files all print BADARG and write nothing. A malformed line
# refuses the plan too: a range this program cannot read is a range it could
# silently collide with.
#
# A candidate block must be free of three things: another account's ranges in
# both files, and any UID the passwd file declares, and any GID the group file
# declares. That last pair is what makes « the block never maps a host account »
# true on a host whose accounts start above UID 100000.
#
# The program never guesses a repair: it reports the reason and the block a
# repair would need.

function overlap(a_start, a_end, b_start, b_end) {
    return a_start < b_end && b_start < a_end
}

# Ranges of the target account in one file, through the caller's arrays.
function target_ranges(file, start, count,   i, n) {
    n = 0
    for (i = 1; i <= total; i++) {
        if (r_file[i] == file && r_name[i] == user) {
            n++
            start[n] = r_start[i]
            count[n] = r_count[i]
        }
    }
    return n
}

# The first aligned block of `size` at or after `base` that no other account
# holds. A candidate that overlaps a range jumps to the next aligned block that
# can be free, so the search is proportional to the number of ranges and never
# walks a billion single-UID candidates. Sets chosen_start, returns 1, or returns
# 0 when the aligned blocks would pass 2^32.
function free_block(   k, s, e, i, jump, blocked) {
    k = 0
    while (1) {
        s = base + k * size
        if (s + size - 1 > uid_max) {
            return 0
        }
        e = s + size
        jump = k + 1
        blocked = 0
        for (i = 1; i <= total; i++) {
            # The target account's own subordinate ranges are the ones a repair
            # replaces; its passwd and group lines are host identifiers, like
            # every other account's, and the block must avoid them too.
            if ((r_file[i] == "uid" || r_file[i] == "gid") && r_name[i] == user) {
                continue
            }
            if (overlap(s, e, r_start[i], r_start[i] + r_count[i])) {
                blocked = 1
                jump = int((r_start[i] + r_count[i] - base + size - 1) / size)
                if (jump <= k) {
                    jump = k + 1
                }
            }
        }
        if (!blocked) {
            chosen_start = s
            return 1
        }
        k = jump
    }
}

function conflict_with(start, count, file,   i, e) {
    e = start + count
    for (i = 1; i <= total; i++) {
        if (r_file[i] != file) {
            continue
        }
        if ((file == "uid" || file == "gid") && r_name[i] == user) {
            continue
        }
        if (overlap(start, e, r_start[i], r_start[i] + r_count[i])) {
            return r_name[i]
        }
    }
    return ""
}

function remove_account_ranges(   i) {
    for (i = 1; i <= total; i++) {
        # Only the two subordinate files hold ranges this account owns; the
        # passwd and group lines are other accounts' identifiers to avoid.
        if ((r_file[i] == "uid" || r_file[i] == "gid") && r_name[i] == user) {
            printf "REMOVE %s %d %d\n", r_file[i], r_start[i], r_count[i]
        }
    }
}

function plan_a_range() {
    if (free_block()) {
        printf "PLAN %d %d\n", chosen_start, size
    } else {
        print "NOFREE"
    }
}

function reject(reason) {
    printf "BADARG %s\n", reason
    rejected = 1
    exit 0
}

BEGIN {
    # The product never asks for more than sixteen default blocks: a bigger range
    # reaches host UIDs that an account created later could take.
    max_count = 1048576
    # A 32-bit uid_t reserves 4294967295 for "no owner", and newuidmap refuses it.
    uid_max = 4294967294
    size = count + 0
    base = base + 0
    if (user !~ /^[A-Za-z0-9._][A-Za-z0-9._-]*$/ || user == "." || user == "..") {
        reject("name")
    }
    if (count !~ /^[0-9]+$/ || size < 1 || size > max_count) {
        reject("count")
    }
    if (base !~ /^[0-9]+$/ || base < 100000 || base + size - 1 > uid_max) {
        reject("base")
    }
}

FNR == 1 {
    seen++
    if (FILENAME == uidfile) {
        file = "uid"
    } else if (FILENAME == gidfile) {
        file = "gid"
    } else if (FILENAME == passwdfile) {
        file = "passwd"
    } else {
        file = "group"
    }
}

{
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) {
        next
    }
    fields = split(line, part, ":")
    if (file == "uid" || file == "gid") {
        if (fields != 3 || part[2] !~ /^[0-9]+$/ || part[3] !~ /^[0-9]+$/ || part[3] + 0 <= 0) {
            printf "BADLINE %s %s\n", file, line
            rejected = 1
            exit 0
        }
        total++
        r_file[total] = file
        r_name[total] = part[1]
        r_start[total] = part[2] + 0
        r_count[total] = part[3] + 0
        next
    }
    if (fields < 3 || part[3] !~ /^[0-9]+$/) {
        printf "BADLINE %s %s\n", file, line
        rejected = 1
        exit 0
    }
    total++
    # A single host UID or GID is a range of one: `free_block` and
    # `conflict_with` already compare ranges, so no second rule is needed.
    r_file[total] = file
    r_name[total] = part[1]
    r_start[total] = part[3] + 0
    r_count[total] = 1
}

END {
    if (rejected) {
        exit 0
    }

    n_uid = target_ranges("uid", u_start, u_count)
    n_gid = target_ranges("gid", g_start, g_count)

    if (n_uid > 1 || n_gid > 1) {
        if (n_uid > 1) {
            printf "MULTI uid %d\n", n_uid
        } else {
            printf "MULTI gid %d\n", n_gid
        }
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    if (n_uid == 1 && n_gid == 0) {
        print "HALF gid"
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    if (n_uid == 0 && n_gid == 1) {
        print "HALF uid"
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    if (n_uid == 0 && n_gid == 0) {
        if (free_block()) {
            printf "ADD %d %d\n", chosen_start, size
            printf "PLAN %d %d\n", chosen_start, size
        } else {
            print "NOFREE"
        }
        exit 0
    }

    if (u_start[1] != g_start[1] || u_count[1] != g_count[1]) {
        printf "MISMATCH %d %d\n", u_start[1], g_start[1]
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    other = conflict_with(u_start[1], u_count[1], "uid")
    if (other == "") {
        other = conflict_with(g_start[1], g_count[1], "gid")
    }
    if (other != "") {
        printf "CONFLICT %d %d %s\n", u_start[1], u_count[1], other
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    if (u_count[1] < size) {
        printf "SMALL %d %d\n", u_start[1], u_count[1]
        remove_account_ranges()
        plan_a_range()
        exit 0
    }
    printf "OK %d %d\n", u_start[1], u_count[1]
}
