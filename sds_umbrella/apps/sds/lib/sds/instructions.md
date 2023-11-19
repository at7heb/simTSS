# CPU Module Implementation

## SDS 940 Instructions

### User Mode Instructions

#### LOAD & STORE

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|STA|35|✅||
|STB|36|✅||
|STX|37|✅||
|XMA|62|✅||
|LDX|71|✅||
|LDB|75|✅||
|LDA|76|✅||
|EAX|77|✅||

#### ARITHMETIC

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|SUB|54|✅||
|ADD|55|✅||
|SUC|56|✅||
|ADC|57|✅||
|MIN|61|✅||
|ADM|63|✅||
|MUL|64|✅||
|DIV|65|✅||

#### BOOLEAN

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|ETR|14|✅||
|MRG|16|✅||
|EOR|17|✅||

#### REGISTER CHANGE

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|CLA|46 00001|✅||
|CLB|46 00002|✅||
|CLAB|46 00003|✅||
|CAB|46 00004|✅||
|CBA|46 00010|✅||
|XAB|46 00014|✅||
|CBX|46 00020|✅||
|CXB|46 00040|✅||
|XXB|46 00060|✅||
|STE|46 00122|✅||
|LDE|46 00140|✅||
|XEE|46 00160|✅||
|CXA|46 00200|✅||
|CAX|46 00400|✅||
|XXA|46 00600|✅||
|CNA|46 01000|✅||
|BAC|46 00012|✅||
|ABC|46 00005|✅||
|CLR|2 46 00003|✅||
|CLX|2 46 00000|✅||
|AXC|46 00401|✅||

#### BRANCH

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|BRU|01|✅||
|BRX|41|✅||
|BRM|43|✅||
|BRR|51|✅||

#### TEST & SKIP

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|SKE|50|✅||
|SKB|52|✅||
|SKN|53|✅||
|SKR|60|✅||
|SKM|70|✅||
|SKA|72|✅||
|SKG|73|✅||
|SKD|74|✅||

#### SHIFT

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|LRSH|66 24XXX|✅||
|RSH|66 00XXX|✅||
|RCY|66 20XXX|✅||
|LSH|67 00XXX|✅||
|LCY|67 20XXX|✅||
|NOD|67 10XXX|✅||
|NODCY|67 30XXX|✅||

#### CONTROL

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|HLT|00|✅||
|NOP|20|✅||
|EXU|23|✅||

#### OVERFLOW

|mnemonic|opcode|impl|test|
|--------|------|----|----|
|ROV|02 20001|✅||
|REO|02 20010|✅||
|OVT|40 20001|✅||
