import std.algorithm.iteration : filter, joiner, map, fold, uniq;
import std.algorithm.searching : all, canFind, until;
import std.algorithm.sorting : sort;
import std.algorithm.mutation : reverse;
import std.array;
import std.ascii : isASCII, isDigit;
import std.conv : to;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.json;
import std.range : chain, chunks, empty, iota, zip;
import std.stdio;
import std.string : indexOf;
import std.traits;
import std.typecons;
import std.uni : toLower;
import std.utf;

import core.thread;
import core.time;

import rest;
import graphql;
import markdown;
import analysis;
import cliargs;
import gitauthors;
import github;
import json;
import getopenissues;
import allpeople;
import githubmigrationapi;

auto toInclude() {
auto ret = 
	[ "op_sys":
		[ "000000"
		, "2F4F4F"
		, "696969"
		, "708090"
		, "808080"
		, "778899"
		, "A9A9A9"
		, "C0C0C0"
		, "D3D3D3"
		, "DCDCDC"
		]
	, "platform": 
		[ "8B0000"
		, "FF0000"
		, "B22222"
		, "DC143C"
		, "CD5C5C"
		, "F08080"
		, "FA8072"
		, "E9967A"
		, "FFA07A"
		]
	, "priority":
		[ "FF4500"
		, "FF6347"
		, "FF8C00"
		, "FF7F50"
		, "FFA500"
		]
	, "resolution":
		[ "4B0082"
		, "800080"
		, "8B008B"
		, "9400D3"
		, "483D8B"
		, "8A2BE2"
		, "9932CC"
		, "FF00FF"
		, "FF00FF"
		, "6A5ACD"
		, "7B68EE"
		, "BA55D3"
		, "9370DB"
		, "DA70D6"
		, "EE82EE"
		, "DDA0DD"
		, "D8BFD8"
		, "E6E6FA"
		]
	, "severity":
		[ "000080"
		, "00008B"
		, "0000CD"
		, "0000FF"
		, "191970"
		, "4169E1"
		, "4682B4"
		, "1E90FF"
		, "00BFFF"
		, "6495ED"
		, "87CEEB"
		, "87CEFA"
		, "B0C4DE"
		, "ADD8E6"
		, "B0E0E6"
		]
	/*, "status":
		[ "006400"
		, "008000"
		, "556B2F"
		, "228B22"
		, "2E8B57"
		, "808000"
		, "6B8E23"
		, "3CB371"
		, "32CD32"
		, "00FF00"
		, "00FF7F"
		, "00FA9A"
		, "8FBC8F"
		, "66CDAA"
		, "9ACD32"
		, "7CFC00"
		, "7FFF00"
		, "90EE90"
		, "ADFF2F"
		, "98FB98"
		]*/
	];
	return ret;
}

string atReplace(string s) {
	return s.replace("@safe", "`@safe`")
		.replace("@trusted", "`@trusted`")
		.replace("@system", "`@system`");
}

Comment[] allComment() {
	return dirEntries("issues/", "bug*.json", SpanMode.depth)
			.filter!(it => canFind(it.name, "comment"))
			.map!((de) {
				string d = readText(de.name);
				return !d.empty
					? parseComment(parseJSON(d))
					: [];
			})
			.joiner
			.array;
}

Comment[] getCommentByBugId(long id) {
	Comment[] parse(string f) {
		const t = readText(f);
		return t.empty
			? []
			: parseComment(parseJSON(t));
			//: [];
	}

	const fn = format("issues/bug%d_comments.json", id);
	return exists(fn)
		? parse(fn)
		: [];
}

Bug[] allBugs() {
	if(!exists("issues")) {
		mkdir("issues");
	}
	return dirEntries("issues/", "bug*.json", SpanMode.depth)
			.filter!(it => !canFind(it.name, "comment"))
			.map!((de) {
				string d = readText(de.name);
				return !d.empty
					? parseBugs(parseJSON(d))
					: [];
			})
			.joiner
			.array;
}

Nullable!Bug getBugById(long id) {
	const fn = format("issues/bug%d.json", id);
	Bug[] bugs = exists(fn)
		? readText(fn).parseJSON().parseBugs()
		: [];
	
	if(bugs.empty) {
		return Nullable!(Bug).init;
	}

	bugs[0].comments = getCommentByBugId(bugs[0].id);
	Nullable!Bug ret;
	ret = bugs[0];
	return ret;
}

string[] allVersions(Bug[] b) {
	auto versions = b
		.map!(b => b.version_)
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return versions;
}

auto getImplSingle(string mem)(Bug[] b) {
	auto arr = b
		.map!(b => __traits(getMember, b, mem))
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return arr;
}

auto getImplMultiple(string mem)(Bug[] b) {
	auto arr = b
		.map!(b => __traits(getMember, b, mem))
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.joiner
		.filter!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return !it.isNull();
			} else {
				return true;
			}
		})
		.map!((it) {
			static if(is(typeof(it) : Nullable!F, F)) {
				return it.get();
			} else {
				return it;
			}
		})
		.array
		.sort!((a,b) => a < b)
		.array
		.uniq!((a,b) => a == b)
		.array;
	return arr;
}

auto all(string mem,T)(Bug[] b) {
	static if(isArray!T && !isSomeString!T) {{
		return getImplMultiple!mem(b);
	}} else {{
		return getImplSingle!mem(b);
	}}
}

Bug[long] joinBugsAndComments(Bug[] bugs, Comment[] comments) {
	Bug[long] ret = assocArray(bugs.map!(it => it.id), bugs);
	foreach(c; comments) {
		Bug* b = c.bug_id in ret;
		if(b !is null) {
			if(b.comments.isNull()) {
				b.comments = [ c ];
			} else {
				b.comments.get() ~= c;
			}
		} else {
			writefln("Bug with id is not found %s", c.bug_id);
		}
	}

	return ret;
}

Person[] buildAllPersons(Bug[] b) {
	Person[] allPersons = b
		.map!(b => b.cc_detail ~ b.assigned_to_detail ~ b.creator_detail)
		.joiner
		.filter!(it => it.email.length > 2 
				&& it.name.length > 2 
				&& it.real_name.length > 2)
		.map!(p => Person(p.id, p.email.toLower(), p.name, p.real_name))
		.array
		.sort!((a,b) => a.id < b.id)
		.array
		.uniq!((a,b) => a.id == b.id)
		.array;
	return allPersons;
}

Unifier getUnifier(Person[] allPersons) {
	Unifier uf = getAllGitPersonsUnifier();
	foreach(it; allPersons) {
		uf.insert(it);
	}

	UnifiedGitPerson[] afterGithub;
	foreach(idx, UnifiedGitPerson it; uf.getUniq()) {
		GithubPerson gh = buildGithubPerson(it);
		Thread.sleep( dur!("seconds")(10) );
		if(!gh.githubUserName.isNull()) {
			it.githubUsername = gh.githubUserName.get();
		} else {
			writefln("%(%s, %) ;; NOT FOUND", gh.gitAuthors.emails);
			if(exists("no_matches.json")) {
				JSONValue[] v = parseJSON(readText("no_matches.json")).arrayNoRef;
				v ~= it.toJSON();
				auto f = File("no_matches.json", "w");
				f.writeln(JSONValue(v).toPrettyString());
			} else {
				auto f = File("no_matches.json", "w");
				f.writeln(JSONValue([it.toJSON()]));
			}
		}
		afterGithub ~= it;
	}
	JSONValue d = JSONValue(["people" : afterGithub.map!(i =>
				i.toJSON()).array]);
	auto f = File("all_people.json", "w");
	f.writeln(d.toPrettyString());

	return uf;
}

struct UnifiedGitPersonLoaded {
	string[] names;
	string[] emails;
	Nullable!string githubUsername;
	Person bugzillaPerson;

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(["names": this.names, "emails": this.emails]);
		ret["bugzillaPerson"] = this.bugzillaPerson.toJSON();
		ret["githubUsername"] = this.githubUsername.isNull()
			? JSONValue(null)
			: JSONValue(this.githubUsername.get());
		return ret;
	}
}

struct GithubPersonMultiple {
	UnifiedGitPersonLoaded gitAuthors;
	GithubRestResult[] github; // etc. @burner

	JSONValue toJSON() const {
		JSONValue ret = JSONValue(
			[ "gitAuthors": this.gitAuthors.toJSON()
			, "github": JSONValue(this.github.map!(it => it.toJSON()).array)
			]);
		return ret;
	}
}

GithubPersonMultiple buildGithubPersonNotJustOne(UnifiedGitPersonLoaded ugp) {
	GithubPersonMultiple ret;
	ret.gitAuthors = ugp;
	foreach(it; chain(ugp.emails
				, ugp.names
				, [ugp.bugzillaPerson.email, ugp.bugzillaPerson.name, ugp.bugzillaPerson.real_name]
			)
			.filter!(it => !it.empty)
			.filter!(it => it.all!(isASCII))
		) 
	{
		GithubRestResult r = getByEmail(it);
		ret.github ~= r;
	}
	return ret;
}

UnifiedGitPersonLoaded[] loadAllGithubPersonWithoutGithubUsername() {
	JSONValue sv = readText("all_people.json").parseJSON();
	return tFromJson!(UnifiedGitPersonLoaded[])(sv["people"])
		.filter!(p => p.githubUsername.isNull())
		.map!(p => UnifiedGitPersonLoaded(p.names.filter!(n => !n.empty).array
					, p.emails.filter!(e => !e.empty).array, p.githubUsername
					, p.bugzillaPerson))
		.filter!(p => !p.names.empty 
				|| !p.emails.empty
				|| p.bugzillaPerson.id != 0
				|| !p.bugzillaPerson.email.empty
				|| !p.bugzillaPerson.name.empty
				|| !p.bugzillaPerson.real_name.empty)
		.array;
}

UnifiedGitPersonLoaded[] loadAllGithubPersonWithGithubUsername() {
	JSONValue sv = readText("all_people.json").parseJSON();
	return tFromJson!(UnifiedGitPersonLoaded[])(sv["people"])
		.filter!(p => p.githubUsername.isNull())
		.map!(p => UnifiedGitPersonLoaded(p.names.filter!(n => !n.empty).array
					, p.emails.filter!(e => !e.empty).array, p.githubUsername
					, p.bugzillaPerson))
		.filter!(p => !p.names.empty 
				|| !p.emails.empty
				|| p.bugzillaPerson.id != 0
				|| !p.bugzillaPerson.email.empty
				|| !p.bugzillaPerson.name.empty
				|| !p.bugzillaPerson.real_name.empty)
		.array;
}

UnifiedGitPersonLoaded[] loadAllGithubPerson() {
	JSONValue sv = readText("all_people.json").parseJSON();
	return tFromJson!(UnifiedGitPersonLoaded[])(sv["people"])
		.map!(p => UnifiedGitPersonLoaded(p.names.filter!(n => !n.empty).array
					, p.emails.filter!(e => !e.empty).array, p.githubUsername
					, p.bugzillaPerson))
		.filter!(p => !p.names.empty 
				|| !p.emails.empty
				|| p.bugzillaPerson.id != 0
				|| !p.bugzillaPerson.email.empty
				|| !p.bugzillaPerson.name.empty
				|| !p.bugzillaPerson.real_name.empty)
		.array;
}

void writeOpenIssuesToFile() {
	Bug[] b = allBugs();
	auto bo = b
		.filter!(it => it.status != "CLOSED" && it.status != "RESOLVED")
		.map!(it => it.id)
		.array
		.sort
		.release;
		
	JSONValue openIssues;
	openIssues["openIssues"] = JSONValue(bo);
	auto f = File("openissues.json", "w");
	f.writeln(openIssues.toPrettyString());
}

Bug[] readOpenIssues() {
	enforce(exists("openissues.json"));
	JSONValue openIssues = readText("openissues.json")
		.parseJSON();
	return openIssues["openIssues"].arrayNoRef
		.map!(j => j.get!int)
		.map!(i => readText(format("issues/bug%s.json", i)))
		.map!(t => parseJSON(t))
		.map!(j => j["bugs"])
		.map!(j => j.tFromJson!(Bug[])())
		.joiner
		.array;
}

void analyzeUnfinshedGithubUsers() {
	UnifiedGitPersonLoaded[] nullPeople =
		loadAllGithubPersonWithGithubUsername();
	GithubPersonMultiple[] rslt;

	foreach(it; nullPeople) {
		auto gh = buildGithubPersonNotJustOne(it);
		Thread.sleep( dur!("seconds")(8) );
		rslt ~= gh;
	}
	JSONValue openIssues;
	openIssues["analyzed"] = JSONValue(rslt
			.map!(it => it.toJSON())
			.array);
	auto f = File("analyzed_people.json", "w");
	f.writeln(openIssues.toPrettyString());
}

void analyzeAllGithubUsers() {
	UnifiedGitPersonLoaded[] nullPeople = loadAllGithubPerson();
	GithubPersonMultiple[] rslt;

	foreach(it; nullPeople) {
		auto gh = buildGithubPersonNotJustOne(it);
		Thread.sleep( dur!("seconds")(8) );
		rslt ~= gh;
	}
	JSONValue openIssues;
	openIssues["analyzed"] = JSONValue(rslt
			.map!(it => it.toJSON())
			.array);
	auto f = File("all_analyzed_people.json", "w");
	f.writeln(openIssues.toPrettyString());
}

/**
Afterwards send fixup PR's to fix issue numbers in the
dmd, druntime, phobos. Thank you WebFreak for the idea
*/


Label[string] generateLabels(string org, string repoName
		, Bug[] ob
		, const(string[][string]) toIncludeKeys
		, Repository target) 
{
	Label[string] labels;
	if(exists("labels.json")) {
		labels = parseExistingLabels()
			.map!(l => tuple(l.name, l))
			.assocArray();
	}
	static foreach(mem; __traits(allMembers, Bug)) {{
		//static if(canFind(toIncludeKeys, mem)) {
		if(mem in toIncludeKeys) {
			alias MT = typeof(__traits(getMember, Bug, mem));
			static if(is(MT == string) || is(MT == string[])) {{
				string[] toInsert = all!(mem,MT)(ob)
					.filter!(it => !it.empty)
					.filter!(it => it != "All" && it != "Other")
					.array;
				writefln("All %s %s %s", mem, toInsert, ob.length);
				const string[] colors = toIncludeKeys[mem];
				foreach(lr; zip(toInsert, colors)
						.map!(p => LabelInput(p[1], p[0], target.id))
						.filter!(li => li.name !in labels)
						.map!(li => createLabel(org, repoName, li, theArgs().githubToken))
				) {
					labels[lr.name] = lr;
				}
			}}
		}
	}}

	if(!labels.empty) {
		JSONValue labelJson = JSONValue(labels
			.values()
			.map!(it => JSONValue(
					[ "id" : it.id
					, "color" : it.color
					, "name" : it.name
					]
				))
			.array
		);

		auto labelFile = File("labels.json", "w");
		labelFile.write(labelJson.toPrettyString());
	}
	return labels;
}

void writeToFiles(Bug[] bugs) {
	//writefln("how many %s", bugs.length);
	foreach(b; bugs) {
		const fn = format("issues/bug%s.json", b.id);
		if(exists(fn)) {
			writefln("%s %s %s", b.id, fn, b.lastTouched.get().toISOExtString());
			continue;
		}
		auto f = File(fn, "w");
		f.writeln(toJson(b).toPrettyString());
	}
}

Bug[] downloadOpenBugsAndUnifyWithLocalCopy(string project) {
	BugDate[] issues = getOpenIssuesImpl(project);
	Bug[long] alreadyLoadedBugs = allBugs()
		.map!(b => tuple(b.id, b))
		.assocArray;
	//writefln("%(%s\n%)", alreadyLoadedBugs.keys()
	//		.chunks(10));

	BugDate[] issuesFiltered = issues
		.filter!((i) {
			auto g = i.id in alreadyLoadedBugs;
			if(g is null) {
				return true;
			} else {
				const r = i.date != (*g).lastTouched.get();
				return r;
			}
		})
		.array;

	writefln("sto %5s\nall %5s\nfil %5s", alreadyLoadedBugs.length, issues.length
			, issuesFiltered.length);

	Bug[] bs = downloadAsChunks(issuesFiltered, 7);
	Bug[] bsAC = downloadCommentsAndAttachments(bs, 7);
	writeToFiles(bsAC);
	writeln(bsAC.length);
	return bsAC;
}

struct BugIssue {
	CreateIssueResult githubIssue;
	Bug bugzillaIssue;
}

void cloneAndBuildStats() {
	string[] repos = [ "https://github.com/dlang/phobos.git"
		, "https://github.com/dlang/dmd.git"];
	string[] dirs = ["repos/phobos", "repos/dmd"];

	if(!exists("repos")) {
	 	mkdir("repos");
	}
	foreach(i; 0 .. repos.length) {
		//execute(["git", "clone", repos[i], dirs[i]]);
		chdir(dirs[i]);
		auto r = execute(["../gitlogjson.sh"]);
		auto f = File("stats.json", "w");
		f.writeln(r.output);
		chdir("../..");
	}
}

/*
dub build && ./d_bugzilla_to_github --organization=GH_PROJECT \
	--project=GH_REPO --bugzillaUsername=BZ_Username \
	--bugzillaPassword=BZ_PASSWORD \
	--token=GH_CLASSIC_TOKEN \
	--components=(dmd|phobos|druntime|tools) \
	-g (dmd|phobos|druntime|tools) \
	--newMigrationApi=true \
	--mentionPeopleInGithubAndPostOnBugzilla=true // THIS ONE is for prod only
*/
void main(string[] args) {
	if(parseOptions(args)) {
		return;
	}

	if(theArgs().buildAllPeople) {
		import allpeople2;
		AllPeopleJoined apj;
		apj.loadFromIssues();
		return;
	}

	Token token;
	if(theArgs().bugzillaTest) {
		token = bugzillaLogin(theArgs().bugzillaUsername, theArgs().bugzillaPassword);
		long githubTestIssue = 23609;
		JSONValue r = postComment(githubTestIssue, "This is a test", token.token);
		return;
	} else if(!theArgs().bugzillaPassword.empty
			&& !theArgs().bugzillaUsername.empty) 
	{
		token = bugzillaLogin(theArgs().bugzillaUsername, theArgs().bugzillaPassword);
	}

	Bug[] bugsOfProject;
	// Get issues for a specific project (dmd, druntime, phobos)
	if(!theArgs().getOpenBugs.empty) {
		bugsOfProject = downloadOpenBugsAndUnifyWithLocalCopy(
				theArgs().getOpenBugs
			);
	}

	// We need to get all open bugs
	if(theArgs().getAllBugs) {
		foreach(p; ["dmd", "druntime", "phobos", "tools", "visuald"]) {
			writefln("getting bugs from bugzilla for '%s'", p);
			bugsOfProject ~= downloadOpenBugsAndUnifyWithLocalCopy(p);
		}
	}

	// This is needed to get github authors, which are later matched to
	// bugzilla authors
	if(theArgs().cloneRepos) {
		cloneAndBuildStats();
	}

	Bug[] ob;

	if(theArgs().findGithubUserMatches) {
 		ob = allBugs();
		Unifier uf = getUnifier(buildAllPersons(ob));
		return;
	}

	if(!theArgs().components.empty) {
		ob = allBugs()
			.filter!(b => canFind(theArgs().components, b.component))
			.array;
		writefln("%s bugs", ob.length);
	}

	ob.sort!((a,b) => a.id < b.id).array;

	AllPeopleHandler aph;
	aph.load();

	Repository target = getRepository(theArgs().githubOrganization
			, theArgs().githubProject, theArgs().githubToken);

	Label[string] labelsAA = generateLabels(theArgs().githubOrganization
			, theArgs().githubProject, ob, toInclude, target);

	const string[] toIncludeKeys = toInclude.keys();

	//writeln(getCurrentRateLimit(theArgs().githubToken));

	if(token.token.empty) {
		writeln("You need a bugzilla token at this point\n"
				~ "Please pass the 'bugzillaUsername' and "
				~ "bugzillaPassword.");
		return;
	}

	BugIssue[] rslt;
	outer: foreach(idx, ref b; ob) {
		//if(idx < theArgs().offset) {
		//	continue outer;
		//}
		//if(idx - theArgs().offset > theArgs().limit) {
		//	break outer;
		//}
		const fstr = "%4s of %4s : BZ_ID %5s";
		if(theArgs().limit != 0) {
			writefln(fstr, idx, theArgs().limit, b.id);
		} else {
			writefln(fstr, idx, ob.length, b.id);
		}
		if(theArgs().newMigrationApi) {
			rslt ~= newApiRunner(b, labelsAA, toIncludeKeys, aph);
		} else {
			Markdowned m = toMarkdown(b, aph);

			CreateIssueInput input;
			input.title = m.title.atReplace();
			input.body_ = (m.header ~ "\n" ~ m.comments).atReplace();
			input.repoId = target.id;
			static foreach(mem; __traits(allMembers, Bug)) {{
				static if(canFind(toIncludeKeys, mem)) {
					alias MT = typeof(__traits(getMember, Bug, mem));
					static if(is(MT == string)) {{
						auto has = __traits(getMember, b, mem);	
						if(has in labelsAA) {
							input.labelIds ~= labelsAA[has].id;
						}
					}} else static if(is(MT == string[])) {{
						auto has = __traits(getMember, b, mem);	
						foreach(it; has) {
							if(it in labelsAA) {
								input.labelIds ~= labelsAA[it].id;
							}
						}
					}}
				}
			}}

			// Annoying creation rate limit of github
			inner: foreach(tries; 0 .. 2) {
				try {
					auto tmp = BugIssue(createIssue(input, theArgs().githubToken), b);
					rslt ~= tmp;
					// comment in the old bugzilla issue
					if(theArgs().mentionPeopleInGithubAndPostOnBugzilla) {
						bzl2: foreach(bz; 0 .. 2) {
							try {
								postComment(b.id, format("THIS ISSUE HAS BEEN MOVED TO GITHUB\n\n"
										~ "https://github.com/%s/%s/issues/%d\n\n"
										~ "DO NOT COMMENT HERE ANYMORE, NOBODY WILL SEE IT "
										~ "THIS ISSUE HAS BEEN MOVED TO GITHUB"
										, theArgs().githubOrganization
										, theArgs().githubProject
										, tmp.githubIssue.number)
									, token.token);
							} catch(Exception e) {
								writefln("Failed to tell bugzilla that issue %s now is"
										~ " github issue %s", b.id
										, tmp.githubIssue.number);
								continue bzl2;
							}
						}
					} else {
						writefln("THIS ISSUE HAS BEEN MOVED TO GITHUB\n\n"
								~ "https://github.com/%s/%s/issues/%d\n\n"
								~ "DO NOT COMMENT HERE ANYMORE, NOBODY WILL SEE IT "
								~ "THIS ISSUE HAS BEEN MOVED TO GITHUB"
								, theArgs().githubOrganization
								, theArgs().githubProject
								, tmp.githubIssue.number);
					}
					continue outer;
				} catch(Exception e) {
					if(e.msg.indexOf("was submitted too quickly") != -1) {
						writefln("Sleeping for an 61 minutes in %s",
								__FUNCTION__);
						Thread.sleep(dur!"minutes"(61));
						continue inner;
					}
				}
			}
			writefln("Failed two of two tries of bug %s", b.id);
			Thread.sleep(dur!"msecs"(5000));
		}
	}
	Thread.sleep( dur!("seconds")(30) );
	if(theArgs().newMigrationApi) {
		foreach(it; rslt) {
			postToBugzillaWithNewApi(it, token);
		}
	}
}

string extractIssueId(string s) {
	try {
		string ret = s.byChar()
			.map!(it => cast()it)
			.array
			.reverse
			.until!(it => !isDigit(it))
			.array
			.reverse
			.to!string();
		return ret;
	} catch(Exception e) {
		writeln(e.toString());
	}
	return "";
}

void postToBugzillaWithNewApi(BugIssue it, Token token) {
	string url;
	try {
		MigrationResult e = getImportStatus(it, theArgs().githubToken);
		url = format("https://github.com/%s/%s/issues/%s"
				, theArgs().githubOrganization
				, theArgs().githubProject
				, extractIssueId(e.issue_url)
			);
	} catch(Exception e) {
		writefln("Failed to find bugzilla issue %s in github issues with error"
				~ " %s", it.bugzillaIssue.id, e.toString());
		return;
	}
	if(theArgs().mentionPeopleInGithubAndPostOnBugzilla) {
		foreach(bz; 0 .. 2) {
			try {
				postComment(it.bugzillaIssue.id, format("THIS ISSUE HAS BEEN MOVED TO GITHUB\n\n"
						~ "%s\n\n"
						~ "DO NOT COMMENT HERE ANYMORE, NOBODY WILL SEE IT, "
						~ "THIS ISSUE HAS BEEN MOVED TO GITHUB"
						, url)
					, token.token);
				return;
			} catch(Exception e) {
				writefln("Failed to tell bugzilla that issue %s now is"
						~ " a github issue\n%s", it.bugzillaIssue.id
						, e.toString());
			}
		}
	} else {
		writefln("THIS ISSUE HAS BEEN MOVED TO GITHUB\n\n"
				~ "%s\n\n"
				~ "DO NOT COMMENT HERE ANYMORE, NOBODY WILL SEE IT, "
				~ "THIS ISSUE HAS BEEN MOVED TO GITHUB"
				, url);
	}
	
}

BugIssue newApiRunner(Bug b, Label[string] labelsAA
		, const string[] toIncludeKeys, AllPeopleHandler aph)
{
	BugIssue tmp;
	Migration mi = bugToMigration(b, aph, labelsAA,
			toIncludeKeys);
	Exception ret;
	foreach(it; 0 .. 2) {
		try {
			return BugIssue(createMigrationissue(mi, theArgs().githubToken), b);
		} catch(Exception e) {
			ret = e;
			if(e.msg.indexOf("was submitted too quickly") != -1) {
				writeln("Sleeping for an 61 minutes");
				Thread.sleep(dur!"minutes"(61));
			}
		}
	}
	writefln("Failed two of two tries of bug %s new API", b.id);
	Thread.sleep(dur!"msecs"(5000));
	throw ret;
}
