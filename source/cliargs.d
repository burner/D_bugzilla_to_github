module cliargs;

import args : Arg, Optional, parseArgsWithConfigFile, printArgsHelp;

struct Args {
	@Arg("The github username to use", Optional.yes)
	string githubUsername;
	@Arg("The github access token", Optional.yes)
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
	bool helpWanted = parseArgsWithConfigFile(theArgsWriteable(), args);

	if (helpWanted) {
		printArgsHelp(theArgsWriteable(), "A text explaining the program");
		return true;
	}
	return false;
}
