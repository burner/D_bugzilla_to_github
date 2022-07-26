struct SysTime {
	static SysTime fromISOExtString(string input) {
		// do you really want to parse
		// YYYY-MM-DDTHH:MM:SS.FFFFFFFTZ
	}
}

struct Date {
	static Date fromISOExtString(string input) {
		// YYYY-MM-DD easier
	}
}
