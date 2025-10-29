{
	"targets": [
		{
			"target_name": "mymodule",
			"cflags!": [ "-fno-exceptions" ],
			"cflags_cc!": [ "-fno-exceptions" ],
			"sources": [ "mylib.c" ],
			"include_dirs": [ "path/to/include" ],
			"libraries": [
				"-lfoo",
				"-lpthread",
				"-Lpath/to/lib",
			]
		}
	]
}
