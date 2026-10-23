# reads a saved game of the real Umoria 5.7.15 (game_save.cpp's svWrite()) and prints the town or level it holds as text:
# the player (with the stats, the pack and the equipment), the map, what lies on it, the monsters, and the six stores with
# their stock, in the same form that zxmoria-state.ps1
# prints ZXMoria's, so that the two can be compared line by line
# usage: python umoria-save.py <save file>
# N.B: every byte after the first four is xor'ed with the byte before it in the file, the fourth is the first key
import sys, struct

MON_MAX_CREATURES, MAX_HEIGHT, MAX_WIDTH = 279, 66, 198
PLAYER_INVENTORY_SIZE, WIELD, OBJECT_IDENT_SIZE, MESSAGE_HISTORY_SIZE, PLAYER_MAX_LEVEL = 34, 22, 448, 22, 40

class Reader:
    def __init__(self, raw):
        self.version = tuple(raw[0:3])
        self.key = raw[3]       # randomNumber(256) - 1, drawn by saveChar() as it began: where the random numbers had got to
        # undo the xor: each byte of the file is the plain byte xor'ed with the file's byte before it
        self.data = bytes(raw[i] ^ raw[i - 1] for i in range(4, len(raw)))
        self.at = 0
    def byte(self):
        v = self.data[self.at]; self.at += 1; return v
    def short(self):
        v = struct.unpack_from('<H', self.data, self.at)[0]; self.at += 2; return v
    def sshort(self):
        v = struct.unpack_from('<h', self.data, self.at)[0]; self.at += 2; return v
    def long(self):
        v = struct.unpack_from('<I', self.data, self.at)[0]; self.at += 4; return v
    def slong(self):
        v = struct.unpack_from('<i', self.data, self.at)[0]; self.at += 4; return v
    def string(self):
        end = self.data.index(0, self.at); v = self.data[self.at:end].decode('latin-1'); self.at = end + 1; return v
    def skip(self, n):
        self.at += n

def item(r):
    it = {}
    it['id'] = r.short(); it['special'] = r.byte(); it['inscription'] = r.string(); it['flags'] = r.long()
    it['category'] = r.byte(); it['sprite'] = r.byte(); it['misc_use'] = r.sshort(); it['cost'] = r.slong()
    it['sub_category'] = r.byte(); it['count'] = r.byte(); it['weight'] = r.short()
    it['to_hit'] = r.sshort(); it['to_damage'] = r.sshort(); it['ac'] = r.sshort(); it['to_ac'] = r.sshort()
    it['dice'] = r.byte(); it['sides'] = r.byte(); it['depth'] = r.byte(); it['identification'] = r.byte()
    return it

def item_text(it):
    # the same fields, in the same order, as zxmoria-state.ps1 prints them, the identification left out: Moria keeps
    # bits in it (e.g. store bought) that are set at other moments, it is compared on its own if ever wanted
    return ('obj {id} cat {category} sub {sub_category} n {count} special {special} p1 {misc_use} cost {cost} wt {weight} '
            'hit {to_hit} dam {to_damage} ac {ac} toac {to_ac} {dice}d{sides} flags {flags:08X}').format(**it)

def main(path, messages_only=False):
    r = Reader(open(path, 'rb').read())
    # the monster memory, up to its sentinel: the kind of creature, then its Recall_t (movement, spells, kills, deaths,
    # defenses, wake, ignore, the four attacks)
    memory = []
    while True:
        i = r.short()
        if i == 0xFFFF: break
        memory.append((i, r.long(), r.long(), r.short(), r.short(), r.short(), r.byte(), r.byte(), [r.byte() for _ in range(4)]))
    flags = r.long()
    name = r.string(); r.skip(1)                    # gender
    pl = {'gold': r.slong(), 'max_exp': r.slong(), 'exp': r.slong()}
    pl['memory'] = memory
    r.skip(2 + 2 + 2 + 2)                           # exp_fraction, age, height, weight
    shorts = [r.sshort() for _ in range(20)]        # level to stealth_factor
    pl['mana'] = shorts[6]; pl['max_hp'] = shorts[7]
    r.skip(4)                                       # class, race, hit die, experience factor
    pl['current_mana'] = r.sshort(); pl['mana_fraction'] = r.short(); pl['hp'] = r.sshort(); pl['hp_fraction'] = r.short()
    for _ in range(4): r.string()                   # history
    pl['stats'] = 'max {} current {} modified {} used {}'.format(
        ' '.join(str(r.byte()) for _ in range(6)), ' '.join(str(r.byte()) for _ in range(6)),
        ' '.join(str(r.sshort()) for _ in range(6)), ' '.join(str(r.byte()) for _ in range(6)))
    pl['status'] = r.long() & ~0x00040000         # PY_SPEED left out: saveChar() sets it itself, by playerChangeSpeed()
    # ...and the bits that only ask for part of the screen to be drawn again at the next turn, PY_ARMOR, PY_STATS, PY_HP
    # and PY_MANA (0xFF400000), ZXMoria draws at once and keeps none of them (found 17 October 2026, the wizard's + left
    # PY_HP set in Umoria with no turn since to clear it)
    pl['status'] &= ~0xFF400000
    counters = [r.sshort() for _ in range(24)]
    pl['rest'] = counters[0]; pl['food'] = counters[4]
    pl['counters'] = ' '.join(str(c) for c in counters[1:])   # blind, paralysis, confused, food, food_digested ... timed_infra
    r.skip(19)                                      # the 18 bools and new spells
    r.skip(2)                                       # missiles counter
    turn = r.slong()
    unique = r.short()
    pl['pack'] = [item(r) for _ in range(unique)]
    pl['equipment'] = [item(r) for _ in range(WIELD, PLAYER_INVENTORY_SIZE)]
    pl['weight'] = r.short(); pl['equipment_count'] = r.short()
    pl['spells'] = 'learnt {:08X} worked {:08X} forgotten {:08X} order {}'.format(r.long(), r.long(), r.long(), ' '.join(str(r.byte()) for _ in range(32)))
    pl['known'] = [r.byte() for _ in range(OBJECT_IDENT_SIZE)]
    magic_seed = r.long(); town_seed = r.long()
    last = r.short()                                # the ring's newest message, Moria's last_message_id
    messages = [r.string() for _ in range(MESSAGE_HISTORY_SIZE)]
    if messages_only:
        for n in range(1, MESSAGE_HISTORY_SIZE + 1):
            m = messages[(last + n) % MESSAGE_HISTORY_SIZE]
            if m: print(m)
        return
    r.skip(2 * 3 + 2 * PLAYER_MAX_LEVEL)
    stores = []
    for _ in range(6):
        st = {'turns_left': r.slong(), 'insults': r.sshort(), 'owner': r.byte()}
        n = r.byte(); st['good'] = r.short(); st['bad'] = r.short(); st['items'] = []
        for _ in range(n):
            cost = r.slong(); st['items'].append((cost, item(r)))
        stores.append(st)
    r.skip(4); died_from = r.string(); r.skip(4); r.skip(4)     # the time, died from, the score, the birth
    if flags & 0x80000000:
        print('the character in this save is dead, there is no level in it, killed by %s' % died_from)
        print('the messages kept: ' + ' / '.join(m for m in messages if m)); return
    level = r.short(); py = r.short(); px = r.short(); r.skip(2)
    height = r.short(); width = r.short(); r.skip(4)
    creatures = {}
    while True:
        y = r.byte()
        if y == 0xFF: break
        x = r.byte(); creatures[(y, x)] = r.byte()
    treasures = {}
    while True:
        y = r.byte()
        if y == 0xFF: break
        x = r.byte(); treasures[(y, x)] = r.byte()
    tiles = []
    while len(tiles) < MAX_HEIGHT * MAX_WIDTH:
        count = r.byte(); value = r.byte(); tiles.extend([value] * count)
    # N.B: the first pair written is a count of 0, see svWrite(), and the last may run past the end
    tiles = tiles[:MAX_HEIGHT * MAX_WIDTH]
    treasure_count = r.short()
    tlist = [None] + [item(r) for _ in range(1, treasure_count)]
    monster_count = r.short()
    mlist = [None, None]
    for _ in range(2, monster_count):
        m = {'hp': r.sshort(), 'sleep': r.sshort(), 'speed': r.sshort(), 'creature': r.short(), 'y': r.byte(), 'x': r.byte()}
        m['distance'] = r.byte(); m['lit'] = r.byte(); m['stunned'] = r.byte(); m['confused'] = r.byte()
        mlist.append(m)
    pl['random'] = r.key
    write(pl, turn, magic_seed, town_seed, level, py, px, height, width, tiles, creatures, treasures, tlist, mlist, stores)

def write(pl, turn, magic_seed, town_seed, level, py, px, height, width, tiles, creatures, treasures, tlist, mlist, stores):
    print('# game'); print(f'turn {turn}')
    print('gold {gold} exp {exp} max_exp {max_exp}'.format(**pl))
    print('hp {hp} hp_fraction {hp_fraction} max_hp {max_hp} mana {current_mana} mana_fraction {mana_fraction} max_mana {mana}'.format(**pl))
    print('food {food} rest {rest} status {status:08X}'.format(**pl))
    # the player's 23 counters after rest, in Moria's order, see zxmoria-state.ps1: blind, paralysis, confused, food,
    # food_digested, protection, speed, fast, slow, afraid, poisoned, image, protect_evil, invulnerability, heroism,
    # super_heroism, blessed, heat and cold resistance, detect_invisible, word_of_recall, see_infra, timed_infra
    print('counters {counters}'.format(**pl))
    print('next random(256) - 1: {random}'.format(**pl))
    print(f'magic seed {magic_seed}'); print(f'town seed {town_seed}')
    print(f'level {level}'); print(f'player {py},{px}'); print(f'size {height}x{width}')
    # the stats, Moria's four sets of six (strength, intelligence, wisdom, dexterity, constitution, charisma), and what
    # is carried, a line for each place in the pack that is used, then each of the 12 places for equipment, in order
    print('# stats'); print(pl['stats'])
    print(f'# pack: {len(pl["pack"])}')
    for i, it in enumerate(pl['pack']): print(f'{i} ' + item_text(it))
    print(f'# carrying: weight {pl["weight"]} equipment {pl["equipment_count"]}')
    print('# spells'); print(pl['spells'])
    # the kinds of thing known, tried and so on (objects_identified, the OD_ bits), a line for each kind that has any
    print('# known kinds')
    for i, k in enumerate(pl['known']):
        if k: print(f'{i} {k:02X}')
    print('# equipment')
    # N.B: an empty place is category 0, TV_NOTHING, which Moria fills with object 417 (OBJ_NOTHING) and ZXMoria with
    # noughts, both games go by the category alone, so both print it as "empty"
    for i, it in enumerate(pl['equipment']): print(f'{i} ' + ('empty' if it['category'] == 0 else item_text(it)))
    # the map: what each square is made of, as a hex digit, then its four flags as a hex digit (Moria's order: lit room,
    # field mark, permanent light, temporary light, the same as ZXMoria's MB_SQUARE_ bits)
    print('# map features')
    for y in range(height):
        print(''.join('%X' % (tiles[y * MAX_WIDTH + x] & 15) for x in range(width)))
    print('# map flags')
    for y in range(height):
        print(''.join('%X' % (tiles[y * MAX_WIDTH + x] >> 4) for x in range(width)))
    print('# things on the map')
    for (y, x) in sorted(treasures):
        print(f'{y},{x} #{treasures[(y, x)]} ' + item_text(tlist[treasures[(y, x)]]))
    print('# monsters on the map')
    for (y, x) in sorted(creatures):
        if creatures[(y, x)] == 1: continue         # 1 is the player
        m = mlist[creatures[(y, x)]]
        print(f'{y},{x} #{creatures[(y, x)]} creature {m["creature"]} hp {m["hp"]} sleep {m["sleep"]} speed {m["speed"]} stunned {m["stunned"]} confused {m["confused"]} distance {m["distance"]} lit {m["lit"]}')
    # the monster memory (creature_recall), a line for each kind of creature that Moria's save keeps: those with anything
    # known but how often one woke or slept on, see svWrite()
    print('# monster memory')
    for (i, movement, spells, kills, deaths, defenses, wake, ignore, attacks) in pl['memory']:
        print(f'{i} movement {movement:08X} spells {spells:08X} kills {kills} deaths {deaths} defenses {defenses:04X} wake {wake} ignore {ignore} attacks ' + ' '.join(str(a) for a in attacks))
    for n, st in enumerate(stores):
        print(f'# store {n}: owner {st["owner"]} items {len(st["items"])} turns_left {st["turns_left"]} insults {st["insults"]} good {st["good"]} bad {st["bad"]}')
        for cost, it in st['items']:
            print(f'paid {cost} ' + item_text(it))

if __name__ == '__main__':
    main(sys.argv[1], '--messages' in sys.argv[2:])
