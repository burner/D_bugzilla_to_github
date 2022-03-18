import std.array;
import std.stdio;
import std.exception;
import std.ascii : isASCII;
import std.algorithm.iteration : filter, joiner, map, fold, uniq;
import std.algorithm.searching : all, canFind;
import std.algorithm.sorting : sort;
import std.range : chain, chunks, zip;
import std.traits;
import std.json;
import std.file;
import std.format;
import std.typecons;
import std.uni : toLower;
import std.range : iota;

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

string[] allKeywords(Bug[] b) {
	return all!("keywords",string[])(b);
}

string[] allVersion(Bug[] b) {
	return all!("version_",string)(b);
}

string[] allCC(Bug[] b) {
	return all!("cc",string[])(b);
}

string[] allPlatforms(Bug[] b) {
	return all!("platform",string)(b);
}

string[] allOPs(Bug[] b) {
	return all!("op_sys",string)(b);
}

string[] allClassification(Bug[] b) {
	return all!("classification",string)(b);
}

string[] allFlags(Bug[] b) {
	return all!("flags",string[])(b);
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
		Thread.sleep( dur!("seconds")(8) );
		if(!gh.githubUserName.isNull()) {
			it.githubUsername = gh.githubUserName.get();
		} else {
			writefln("%(%s, %) ;; NOT FOUND", gh.gitAuthors.emails);
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

/*
Label[string] generateLabels(Bug[] ob, string[][string] toIncludeKeys) {
	Label[string] labels;
	static foreach(mem; __traits(allMembers, Bug)) {{
		static if(canFind(toIncludeKeys, mem)) {
			alias MT = typeof(__traits(getMember, Bug, mem));
			static if(is(MT == string) || is(MT == string[])) {{
				string[] toInsert = all!(mem,MT)(ob)
					.filter!(it => !it.empty)
					.filter!(it => it != "All" && it != "Other")
					.array;
				writefln("All %s %s", mem, toInsert);
				const string[] colors = toInclude[mem];
				foreach(lr; zip(toInsert, colors)
						.map!(p => createLabel(LabelInput(p[1], p[0], target.id)
							, theArgs().githubToken)
						)
				) {
					labels[lr.name] = lr;
				}
			}}
		}
	}}

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
	return labels;
}*/

void main(string[] args) {
	if(parseOptions(args)) {
		return;
	}
	long[] issues = getOpenIssuesImpl("phobos");
	auto bs = downloadAsChunks(issues[0 .. 100], 10);
	Bug[] bsAC = downloadCommentsAndAttachments(bs, 10);
	//writeOpenIssuesToFile();
	//Bug[] ob = allBugs();
	/*
	Label[] labels = parseExistingLabels();
	Label[string] labelsAA = assocArray
		( labels.map!(it => it.name)
		, labels
		);
	*/
	/*
	CommentAnalysis ca = readOpenIssues()
		.map!(b => getCommentByBugId(b.id))
		.joiner
		.doCommentAnalysis();
	
	writeln(ca);
	*/

	/*
	BugAnalysis ba = ob
			//.filter!(it => it.component == "phobos")
			.doBugAnalysis();
	writeln(ba);
	*/

	/*
	Nullable!Bug b = getBugById(21565);
	Bug bnn = b.get();
	Markdowned m = toMarkdown(bnn);
	*/
	//auto f = File("i21565.md", "w");
	//f.write(m.toString());

	/*writefln("%(%s\n%)", ob
			.filter!(it => it.component == "phobos")
			.map!(it => it.id));
	*/
	
	/*
	Comment[] c = allComment();

	Bug[long] bugsAA = joinBugsAndComments(b, c);
	*/

	//writefln("%(%s\n%)", loadAllGithubPersonWithoutGithubUsername());
	//analyzeUnfinshedGithubUsers();
	//analyzeAllGithubUsers();

	/*
	Person[] allPersons = buildAllPersons(b);

	writefln("%(%s\n%)", allPersons);
	*/

	/*
	auto notFound = allPersons
		.filter!(p => p.email !in uf.byEmail 
				&& p.name !in uf.byName 
				&& p.real_name !in uf.byName)
		.array;
	writefln("%(%s\n%)", notFound);
	writeln(notFound.length);
	*/

	//writefln("All versions %s", allVersions(ob));
	//writefln("All keywords %s", allKeywords(ob));
	//writefln("All platforms %s", allPlatforms(ob));
	//writefln("All OPs %s", allOPs(ob));
	//writefln("All classifications %s", allClassification(ob));
	//writefln("All flags %s", allFlags(ob));

	/*
	const toInclude = 
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
		, "status":
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
			]
		];

	const string[] toIncludeKeys = toInclude.keys();
	//const string[] toIncludeKeys = [ "platform" ];

	Repository target = getRepository("burner", "bugzilla_migration_test"
			, theArgs().githubToken);

	CreateIssueInput input;
	input.title = m.title;
	input.body_ = m.header ~ "\n" ~ m.comments;
	input.repoId = target.id;
	static foreach(mem; __traits(allMembers, Bug)) {{
		static if(canFind(toIncludeKeys, mem)) {
			alias MT = typeof(__traits(getMember, Bug, mem));
			static if(is(MT == string)) {{
				auto has = __traits(getMember, bnn, mem);	
				if(has in labelsAA) {
					input.labelIds ~= labelsAA[has].id;
				}
			}} else static if(is(MT == string[])) {{
				auto has = __traits(getMember, bnn, mem);	
				foreach(it; has) {
					if(it in labelsAA) {
						input.labelIds ~= labelsAA[it].id;
					}
				}
			}}
		}
	}}

	createIssue(input, theArgs().githubToken);
	*/


	/*
	JSONValue vq;
	vq["name"] = "bugzilla_migration_test";
	vq["owner"] = "burner";
	vq["first"] = 10;


	JSONValue repo = qlQuerySafe(repoInfo, vq
				, theArgs().githubToken
		);
	//writeln(repo.toPrettyString());

	JSONValue v3 = JSONValue(["input": v]);
	writeln(v3.toPrettyString());

	JSONValue createLabelRslt = qlMutationSafe(createLabel, v3,
			theArgs().githubToken);

	writeln(createLabelRslt.toPrettyString());

	return jsonToForgiving!Label(createLabelRslt);
	*/

	//<meta name="octolytics-dimension-repository_id" content="459916112">

	/*
	string lg = `query myself($number_of_repos: Int!) { 
		viewer { 
			login 
			repositories(last: $number_of_repos) {
	     		nodes {
	     			name
	     		}
	   		}
		}
	}`;

	JSONValue v2;
	v2["number_of_repos"] = 3;

	writeln(qlQuerySafe(lg, v2
				, theArgs().githubToken
		).toPrettyString());
	*/

}
