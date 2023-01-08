module cliargs;

import std.getopt;

struct Args {
	string githubUsername = "rburners@gmail.com";
	string githubToken;
	string getOpenBugs;
	string githubOrganization = "burner"; // burner for dev, dlang for prod
	string githubProject = "bugzilla_migration_test";
	string bugzillaUsername;
	string bugzillaPassword;
	bool bugzillaTest;
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
			, "g|getOpenBugs", "Get all open bugs for, for example phobos."
				, &theArgsWriteable().getOpenBugs
			, "o|organization", "The github organization name",
				&theArgsWriteable().githubOrganization
			, "p|project", "The github project name of the github organization",
				&theArgsWriteable().githubProject
			, "b|bugzillaUsername", "Bugzilla Username",
				&theArgsWriteable().bugzillaUsername
			, "d|bugzillaPassword", "Bugzilla Password",
				&theArgsWriteable().bugzillaPassword
			, "bugzillaTest", "Test Bugzilla",
				&theArgsWriteable().bugzillaTest
			);
	if(helpWanted.helpWanted) {
		defaultGetoptPrinter("A text explaining the program",
				helpWanted.options);
		return true;
	}
	return false;
}
