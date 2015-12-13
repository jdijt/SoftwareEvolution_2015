module series2::CloneDetector

import Prelude;
import util::Math;
import lang::java::m3::AST;
import lang::java::m3::Core;

import series2::cfg;
import series2::Util;
import series2::AST::TM;
import series2::AST::Util;
import series2::AST::Normalizer;

//Parameters:

public rel[value,loc] detectClones(M3 projectModel, set[Declaration] decls){
	print("Parsing trees...\n");
	treemodel = initTreeModel(projectModel.id, decls);
	print("Generated <size(treemodel@subtrees)> subtrees.\n");
	
	return detectClones(treemodel);
}
	
public rel[value,loc] detectClones(TM treemodel){
	
	treeChildren = treemodel@treecontainment+;
	treeParents = invert(treemodel@treecontainment)+;
	
	println("Finding Clones...");
	clones = getBasicClones(treemodel, treeChildren, treeParents);
	println("Found <size(clones)> clones before merging sequences.");
	
	println("Finding sequences...");
	clones = getSequences(clones, treemodel, treeChildren, treeParents);
	println("Reduced number of clones to: <size(clones)>");
	
	return clones;
}

public rel[value,loc] getBasicClones(TM treemodel, rel[loc,loc] parentToChild, rel[loc,loc] childToParent){
	rel[value,loc] clones = {};
	
	hashes = domain(treemodel@hashes);
	println("Subtrees split over <size(hashes)> buckets after filtering.");
	
	for(hash <- hashes){
		<curHead, curTail> = takeOneFrom(treemodel@hashes[hash]);
		while(size(curTail) > 0){
			headTree = treemodel@subtrees[curHead];
			for(other <- curTail){
				if(compareTrees(hash, headTree, treemodel@subtrees[other]) >= minPercentageShared){
					//Remove subtrees of other:
					clones = rangeX(clones, parentToChild[{other,curHead}]);
					clones = addClonePair(clones, hash, curHead, other, childToParent);
				}
			}
			<curHead,curTail> = takeOneFrom(curTail);
		}
	}
	
	return clones;
}

public rel[value,loc] getSequences(rel[value,loc] clones, TM treemodel, rel[loc,loc] parentToChild, rel[loc,loc] childToParent){
	seqClones = {};
	
	//Remove all sequences that are children of current clones (i.e. already fully cloned).
	hashes = range(domainX(treemodel@seqhashes, parentToChild[range(clones)]));
	println("<size(range(hashes))> sequences split over <size(domain(hashes))> buckets after filtering.");
	
	
	for(hash <- domain(hashes)){
		<curHead,curTail> = takeOneFrom(hashes[hash]);
		while(size(curTail) > 0){
			//Remove children of head from clones:
			for(other <- curTail){
				if(compareTrees(hash, treemodel@subtrees[toSet(curHead)],treemodel@subtrees[toSet(other)]) >= minPercentageShared){
					clones = rangeX(clones, parentToChild[toSet(other+curHead) + ]);
					seqclones += {<hash,combineLocs(curHead)>,<hash,combineLocs(other)>};
				}
			}
			<curHead,curTail> = takeOneFrom(curTail);
		}
	}
	println("done.");
	iprintln(range(toMap(seqclones)));
	return clones;
}

public rel[value,loc] addClonePair(rel[value,loc] existingClones, value hash, loc n1, loc n2, rel[loc,loc] childToParent){
	//Is this a subclone of an already known one?
	n1Parents = childToParent[n1];
	n2Parents = childToParent[n2];
	existingClonesLocs = range(existingClones);
	
	if(size(n1Parents & existingClonesLocs) > 0 && size(n2Parents & existingClonesLocs) > 0){
		//Parents of both these locs are already clones, don't introducte new subclone.
		//println("Not adding Pair:
		//		'<n1>
		//		'<n2>");
		return existingClones;
	} 
	
	//println("Adding pair:
	//		'<n1>
	//		'<n2>");
	
	return existingClones + {<hash, n1>,<hash,n2>};
}