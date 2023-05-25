# L2Tower
L2Tower scripts and plugins


## Premium enabler (v.1.4.2.XXX)

Files: libs\L2TowerUtils.dll; libs\L2Tower.dll

```
== Original code
50                 push    eax             ; Filename
68 58 C4 6D 10     push    offset unk_106DC458 ; int (the offset here can be different)
E8 04 F0 00 00     call    sub_104C9F20        ;     (the offset here can be different)
83 C4 0C           add     esp, 0Ch
3D 45 53 34 31     cmp     eax, 31345345h

== Replaced with
50                 push    eax             ; Filename
68 58 C4 6D 10     push    offset unk_106DC458 ; int
B8 23 23 31 52     mov     eax, 52312323h
83 C4 0C           add     esp, 0Ch
3D 45 53 34 31     cmp     eax, 31345345h
```

OR without checking for `license.cfg`

```
== Original code
74 12                JZ         LAB_104baba0
a1 20 72 64 10       MOV        EAX,[PTR_DAT_10647220]
c7 00 23 24 23 41    MOV        dword ptr [EAX]=>DAT_1064721c,0x41232423
b8 23 24 23 41       MOV        EAX,0x41232423
eb 66                JMP        LAB_104bac06

== Replaced with
90                   NOP
90                   NOP
a1 20 72 64 10       MOV        EAX,[DAT_10647220]
c7 00 23 24 23 41    MOV        dword ptr [EAX]=>DAT_1064721c,0x41232423
e9 60 04 00 00       JMP        LAB_104baffe
eb 66                JMP        LAB_104bac06
```

## Links

Create license form: http://l2tower.eu/api/create.php

Latest version: http://update.l2tower.eu/update/version

Version index: http://update.l2tower.eu/update/1.4.3.143/L2Tower.Update.xml

Download file by ID: http://update.l2tower.eu/update/1.4.3.143/{ID}

X86 Opcodes and Instructions: http://ref.x86asm.net/coder32-abc.html
