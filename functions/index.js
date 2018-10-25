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
		return admin.database().ref("data/"+map["poll"]+"/a").once("value", (snapshot)=>{
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

exports.create = functions.https.onRequest((req,res)=>{
    var chars = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
    var key = keyFile.key();
    var map = JSON.parse(req.query.text);
    if(map["key"]==key){
        return admin.database().ref("data").once("value",(snapshot)=>{
            var code = "";
            var list = Object.keys(snapshot.val());
            do{
                code = "";
                for(var i = 0;i<4;i++){
                    code+=chars[Math.floor(Math.random()*36)];
                }
            }while(list.includes(code));
            var returned = {
                "a":map["a"],
                "b":map["b"],
                "c":map["c"],
                "q":map["q"],
                "t":Math.floor(Date.now()/1000)
            };
            admin.database().ref("data/"+code).set(returned);
            return res.send(JSON.stringify(code));
        });
    }else{
        return res.send(JSON.stringify({"Error":"No Permissions"}));
    }
});