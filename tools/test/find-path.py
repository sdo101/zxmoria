# plans a walk on a level, from a state file that zxmoria-state.ps1 or umoria-save.py wrote: from where the player stands
# to the nearest thing of the categories asked for, over open squares only (the features up to 3, Moria's MAX_OPEN_SPACE)
# and round anything in the way (traps, rubble, locked, stuck and secret doors, stairs, monsters), and prints the keys,
# one direction digit a step, the last step onto the thing itself, which picks it up; a closed door that is neither
# locked nor stuck (its p1, Moria's misc_use, is 0) is opened on the way, o and the direction, then stepped through,
# Moria's playerMove() says "There is a closed door blocking your way." and goes no further
# usage: python find-path.py <state.txt> <category> [<category> ...]     e.g. 75 76 for potions, 70 71 for scrolls
#        or o and an object's number for that one kind of thing, e.g. o375 for the Temple's door (stores are 372 to 377)
#        or @ and a square, row,column, e.g. @52,118, whatever is there (the last key is the step on to it, which for a
#        door that will not open is where the o, the B or the S goes instead)
# N.B: for comparisons with Umoria (compare-level.ps1 -Keys), the two games' levels being the same, a walk planned on one
# is the walk in both; monsters move meanwhile, the same in both, and one in the way is attacked, also the same in both
import sys
from collections import deque

# categories a step must not go onto: invisible and visible traps, rubble, up and down stairs, secret doors, and closed
# doors (105) unless they open at the first try
BLOCKING = {101, 102, 103, 107, 108, 109}
CLOSED_DOOR = 105
STEPS = [(-1, -1, '7'), (-1, 0, '8'), (-1, 1, '9'), (0, -1, '4'), (0, 1, '6'), (1, -1, '1'), (1, 0, '2'), (1, 1, '3')]


def main(path, wanted):
    lines = open(path).read().splitlines()
    section = None
    features, things, monsters, player = [], {}, set(), None
    objects = {}
    for line in lines:
        if line.startswith('# '):
            section = line[2:].split(':')[0]
            continue
        if section == 'game' and line.startswith('player '):
            player = tuple(int(v) for v in line[7:].split(','))
        elif section == 'map features':
            features.append(line)
        elif section == 'things on the map':
            pos, _, rest = line.partition(' ')
            y, x = (int(v) for v in pos.split(','))
            cat = int(rest.split(' cat ')[1].split()[0])
            p1 = int(rest.split(' p1 ')[1].split()[0])
            obj = int(rest.split(' obj ')[1].split()[0])
            things[(y, x)] = (cat, p1)
            objects[(y, x)] = obj
        elif section == 'monsters on the map':
            y, x = (int(v) for v in line.split(' ')[0].split(','))
            monsters.add((y, x))
    rows, cols = len(features), len(features[0])

    def open_square(y, x):
        if not (0 <= y < rows and 0 <= x < cols): return False
        # N.B: a closed door's square is 4, Moria's TILE_BLOCKED_FLOOR, a way through once the door is open
        if int(features[y][x], 16) > 3 and not (int(features[y][x], 16) == 4 and things.get((y, x), (None, 0))[0] == CLOSED_DOOR): return False
        if (y, x) in monsters: return False
        return True

    seen = {player: None}
    queue = deque([player])
    while queue:
        here = queue.popleft()
        for dy, dx, key in STEPS:
            there = (here[0] + dy, here[1] + dx)
            if there in seen or not (0 <= there[0] < rows and 0 <= there[1] < cols): continue
            cat, p1 = things.get(there, (None, 0))
            # N.B: what is looked for is found whatever its square is made of, a secret door is in a wall, the walk
            # then ends beside it, its last key being the step towards it
            if cat in wanted or ('o%d' % objects.get(there, -1)) in wanted or ('@%d,%d' % there) in wanted:
                seen[there] = (here, key)
                keys = []
                at = there
                while seen[at]:
                    at, k = seen[at][0], seen[at][1]
                    keys.append(k)
                print(''.join(reversed(keys)), f'# to {there}, category {cat}, {len(keys)} steps')
                return
            if not open_square(*there): continue
            if cat in BLOCKING: continue
            if cat == CLOSED_DOOR:
                if p1 != 0: continue
                key = 'o' + key + key
            seen[there] = (here, key)
            queue.append(there)
    print('', '# nothing of those categories can be reached')


if __name__ == '__main__':
    main(sys.argv[1], {(c if c[0] in 'o@' else int(c)) for c in sys.argv[2:]})
