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

## Links

Create license form: http://l2tower.eu/api/create.php

Latest version: http://update.l2tower.eu/update/version

Version index: http://update.l2tower.eu/update/1.4.3.143/L2Tower.Update.xml

Download file by ID: http://update.l2tower.eu/update/1.4.3.143/{ID}
