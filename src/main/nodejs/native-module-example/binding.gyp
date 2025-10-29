{
	"targets": [
		{
			"target_name": "mymodule",
			"sources": [ "mylib.c" ],
			"cflags!": [ "-fno-exceptions" ],
			"cflags_cc!": [ "-fno-exceptions" ]
		}
	]
}
