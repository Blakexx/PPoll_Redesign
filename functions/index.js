const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp();

const keyFile = require('./key');

exports.vote = functions.https.onRequest((req,res)=>{
	var key = keyFile.key();
	const text = req.query.text;
	var map = JSON.parse(text);
	if(map["key"]===key){
		var multiSelect = map["multiSelect"];
		var choice = map["choice"];
		var changedFrom = map["changed"];
		var currentList;
		return admin.database().ref("data/"+map["poll"]+"/a").once('value', (snapshot)=>{
			currentList = snapshot.val();
			if(!multiSelect){
				if(changedFrom!=null){
					currentList[changedFrom]--;
				}
				currentList[choice]++;
			}else{
				currentList[choice]+=!changedFrom?1:-1;
			}
			admin.database().ref("data/"+map["poll"]+"/a").set(currentList);
			return res.send(JSON.stringify(currentList));
		});
	}else{
		return res.send(JSON.stringify({"Error":"No Permissions"}));
	}
});