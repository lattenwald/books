books
=====

Basic books organizer. Understands formats fb2 and fb2.zip, requires "unzip" binary, Perl 5.10 or higher with modules `File::Path`, `File::Temp` and `XML::Fast`.

Help is shown when run with "--help" switch:

```
$ ./books.pl  --help
./books.pl version 1.0 calling Getopt::Std::getopts (version 1.06),
running under Perl version 5.12.5.
Usage: ./books.pl [options] <input directory> <output directory>

Available options:
  -f  force action (actually do stuff, incompatible with -p)
  -p  print actions that would be done if run with -f switch (incompatible with -f)
  -m  move files (default action is just copy)
  -x  perl regexp of files to exclude
  -1  use first element by default in all choices
```

Example

```
$ books.pl -f1 1 2
Total files: 6

$ tree 1
1
├── 93571
│   └── download.fb2.zip
├── 93753
│   └── download.fb2.zip
├── 93836
│   └── download.fb2.zip
├── 93854
│   └── download.fb2.zip
├── 93861
│   └── download.fb2.zip
└── 93872
    └── download.fb2.zip

6 directories, 6 files

$ tree 2
2
├── Аркадий Стругацкий
│   ├── Далекая радуга.fb2.zip
│   ├── Парень из преисподней.fb2.zip
│   ├── Попытка к бегству.fb2.zip
│   ├── Рассказы
│   │   └── Бедные злые люди.fb2.zip
│   └── Трудно быть богом.fb2.zip
└── Лоис Буджолд
    └── Барраяр
        └── 14. Подарки к Зимнепразднику.fb2.zip

4 directories, 6 files
```
