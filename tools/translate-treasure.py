# one-off: turns the regular parts of Moria's treasure.cpp into Boriel BASIC, so that nothing is mistyped by hand
# usage: python translate_treasure.py <treasure.cpp> <out.bas>
import re, sys

src = open(sys.argv[1], encoding='utf-8').read()
src = re.sub(r'//[^\n]*', '', src)
for junk in ('config::treasure::flags::', 'config::identification::', 'SpecialNameIds::', 'config::treasure::chests::', 'config::treasure::'):
    src = src.replace(junk, '')

SKIP = {'magicShouldBeEnchanted', 'magicEnchantmentBonus', 'magicalProjectile'}      # written by hand
FIELDS = {'flags': 'gul_item_flags', 'to_ac': 'gsw_item_to_ac', 'to_hit': 'gsw_item_to_hit', 'to_damage': 'gsw_item_to_damage',
          'cost': 'gsl_item_cost', 'special_name_id': 'gub_item_special_name', 'misc_use': 'gsw_item_misc_use',
          'identification': 'gub_item_identification', 'sub_category_id': 'gub_item_sub_category', 'weight': 'guw_item_weight',
          'items_count': 'gub_item_count', 'depth_first_found': 'gub_item_depth', 'category_id': 'gub_item_category'}

def snake(name):
    return re.sub(r'(?<!^)([A-Z])', r'_\1', name).lower()

def fname(name, returns):
    return ('fsw_mt_' if returns else 's_mt_') + snake(name)

funcs = {}      # C name -> returns a value?
for m in re.finditer(r'^(?:static )?(void|int) (\w+)\(([^)]*)\) \{', src, re.M):
    funcs[m.group(2)] = (m.group(1) == 'int')

def expr(e, names, long_math=False):
    e = e.strip()
    e = re.sub(r'\((?:int16_t|uint16_t|int|uint8_t)\)\s*', '', e)
    e = e.replace('maxDiceRoll(item.damage)', '( Cast( Integer , gub_item_damage_dice ) * gub_item_damage_sides )')
    e = re.sub(r'item\.(\w+)', lambda m: FIELDS[m.group(1)], e)
    e = e.replace('randomNumber(', 'fsw_mt_random(').replace('magicEnchantmentBonus(', 'fsw_mt_bonus(').replace('magicShouldBeEnchanted(', 'fub_mt_should(')
    for c, returns in funcs.items():
        e = re.sub(r'\b' + c + r'\(', fname(c, returns) + '(', e)
    e = re.sub(r'\b(TR_\w+)', r'UL_\1', e)
    e = re.sub(r'\b(CH_\w+)', r'UL_\1', e)
    e = re.sub(r'\b(SN_\w+)', r'UB_\1', e)
    e = re.sub(r'\b(ID_\w+)', r'MB_\1', e)
    e = re.sub(r'\b(TV_\w+)', r'UB_\1', e)
    e = e.replace('==', '=').replace('!=', '<>').replace('&&', ' And ').replace('||', ' Or ').replace('%', ' Mod ')
    e = re.sub(r'(?<![|])\|(?![|])', ' bOr ', e)
    for n, new in names.items():
        e = re.sub(r'\b' + n + r'\b', new, e)
    if long_math:
        e = re.sub(r'\b(gsw_item_\w+)', r'Cast( Long , \1 )', e)
    e = re.sub(r'\s+', ' ', e).replace('( ', '( ').strip()
    return e

def cond(c, names):
    c = c.strip()
    m = re.fullmatch(r'!(\w+\(.*\))', c)
    if m:
        return expr(m.group(1), names) + ' = false'
    return expr(c, names)

out = []
for m in re.finditer(r'^(?:static )?(void|int) (\w+)\(([^)]*)\) \{\n(.*?)^\}\n', src, re.M | re.S):
    rtype, name, params, body = m.groups()
    if name in SKIP:
        continue
    names = {}
    plist = []
    for p in [x.strip() for x in params.split(',') if x.strip()]:
        if 'Inventory_t' in p:
            continue
        pn = p.split()[-1]
        if name == 'magicTreasureMagicalAbility' and pn == 'item_id':
            continue
        names[pn] = 'psw_' + pn
        plist.append('psw_' + pn + ' As Integer')
    # join statements that run over several lines
    lines, pending = [], ''
    for raw in body.split('\n'):
        s = raw.strip()
        if not s:
            continue
        pending = (pending + ' ' + s).strip()
        if pending.endswith((';', '{', '}', ':')) or pending.startswith('} else'):
            lines.append(pending)
            pending = ''
    code, stack, locals_, selectors, ind = [], [], [], 0, 1
    def emit(t):
        code.append('    ' * ind + t)
    for s in lines:
        if s.startswith('Inventory_t &item'):
            continue
        mm = re.fullmatch(r'int (\w+) = (.*);', s)
        if mm:
            names[mm.group(1)] = 'lsw_' + mm.group(1); locals_.append('lsw_' + mm.group(1))
            emit(f"{names[mm.group(1)]} = {expr(mm.group(2), names)}"); continue
        mm = re.fullmatch(r'int (\w+);', s)
        if mm:
            names[mm.group(1)] = 'lsw_' + mm.group(1); locals_.append('lsw_' + mm.group(1)); continue
        mm = re.fullmatch(r'switch \((.*)\) \{', s)
        if mm:
            selectors += 1
            sel = f'lsw_select_{selectors}'
            locals_.append(sel)
            emit(f"{sel} = {expr(mm.group(1), names)}")
            stack.append({'kind': 'switch', 'sel': sel, 'labels': [], 'opened': False, 'default': False})
            continue
        mm = re.fullmatch(r'case (\w+):', s)
        if mm:
            stack[-1]['labels'].append(expr(mm.group(1), names)); continue
        if s == 'default:':
            stack[-1]['default'] = True; continue
        # the first statement after a run of case labels opens that branch
        if stack and stack[-1]['kind'] == 'switch' and (stack[-1]['labels'] or stack[-1]['default']) and s != '}':
            sw = stack[-1]
            if sw['default'] and not sw['labels']:
                if s == 'break;' and not sw['opened']:
                    sw['default'] = False; continue
                if s in ('break;', 'return;') and sw['opened'] and s == 'break;':
                    sw['default'] = False; continue
                ind -= 1 if sw['opened'] else 0
                emit('Else' if sw['opened'] else 'If true Then')
                ind += 1
                sw['opened'] = True
            else:
                test = ' Or '.join(f"{sw['sel']} = {l}" for l in sw['labels'])
                if sw['opened']:
                    ind -= 1
                    emit(f'ElseIf {test} Then')
                else:
                    emit(f'If {test} Then')
                ind += 1
                sw['opened'] = True
            sw['labels'] = []; sw['default'] = False
        if s == 'break;':
            continue
        mm = re.fullmatch(r'if \((.*)\) \{', s)
        if mm:
            emit(f"If {cond(mm.group(1), names)} Then"); ind += 1; stack.append({'kind': 'if'}); continue
        mm = re.fullmatch(r'\} else if \((.*)\) \{', s)
        if mm:
            ind -= 1; emit(f"ElseIf {cond(mm.group(1), names)} Then"); ind += 1; continue
        if s == '} else {':
            ind -= 1; emit('Else'); ind += 1; continue
        if s == '}':
            top = stack.pop()
            if top['kind'] == 'switch':
                if top['opened']:
                    ind -= 1; emit('End If')
            else:
                ind -= 1; emit('End If')
            continue
        if s == 'return;':
            emit('Return'); continue
        mm = re.fullmatch(r'return (.*);', s)
        if mm:
            emit(f"Return {expr(mm.group(1), names)}"); continue
        mm = re.fullmatch(r'(\S+)\+\+;', s)
        if mm:
            t = expr(mm.group(1), names); emit(f"{t} = {t} + 1"); continue
        mm = re.fullmatch(r'(\S+) (\|=|\+=|-=|=) (.*);', s)
        if mm:
            target = expr(mm.group(1), names)
            is_cost = target == 'gsl_item_cost'
            value = expr(mm.group(3), names, long_math=is_cost)
            op = mm.group(2)
            if op == '=':
                emit(f"{target} = {value}")
            elif op == '|=':
                emit(f"{target} = {target} bOr ( {value} )")
            else:
                emit(f"{target} = {target} {op[0]} ( {value} )")
            continue
        mm = re.fullmatch(r'(\w+)\((.*)\);', s)
        if mm and mm.group(1) in funcs:
            args = [a.strip() for a in mm.group(2).split(',') if a.strip() and a.strip() != 'item']
            emit(f"{fname(mm.group(1), funcs[mm.group(1)])}( {' , '.join(expr(a, names) for a in args)} )"); continue
        raise SystemExit(f"cannot translate in {name}: {s}")
    bname = fname(name, rtype == 'int')
    head = ('Function ' if rtype == 'int' else 'Sub ') + bname + ('( ' + ' , '.join(plist) + ' )' if plist else '()') + (' As Integer' if rtype == 'int' else '')
    out.append(head)
    out.append(f"    ' Moria's {name}()")
    seen = []
    for l in locals_:
        if l not in seen:
            seen.append(l)
    if seen:
        out.append('    Dim ' + ' , '.join(seen) + ' As Integer')
        out.append('')
    out.extend(code)
    out.append('End Function' if rtype == 'int' else 'End Sub')
    out.append('')
    out.append('')

open(sys.argv[2], 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print(f"translated {len([1 for l in out if l.startswith(('Sub ', 'Function '))])} routines, {len(out)} lines")
