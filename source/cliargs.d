module cliargs;

import std.getopt;

struct Args {
	string githubUsername = "rburners@gmail.com";
	string githubToken;
}

private Args __theArgs;

ref const(Args) theArgs() {
	return __theArgs;
}

ref Args theArgsWriteable() {
	return __theArgs;
}

bool parseOptions(ref string[] args) {
	auto helpWanted = getopt(args
			, "e|email", "The github username to use", &theArgsWriteable().githubUsername
			, "t|token", "The github access token", &theArgsWriteable().githubToken
			);
	if(helpWanted.helpWanted) {
		defaultGetoptPrinter("A text explaining the program",
				helpWanted.options);
		return true;
	}
	return false;
}
