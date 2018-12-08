const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp();

const keyFile = require('./key');

const profanityFile = require('./profanity');

exports.vote = functions.https.onRequest((req,res)=>{
	let key = keyFile.key();
	const text = req.query.text;
	let map = JSON.parse(text);
	if(map["key"]===key){
		let multiSelect = map["multiSelect"];
		let choice = map["choice"];
		let changedFrom = map["changed"];
		let currentList;
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
    let chars = ["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
    let key = keyFile.key();
    let map = JSON.parse(req.query.text);
    let profanityList = profanityFile.profanityList();
    if(map["key"]===key){
        return admin.database().ref("data").once("value",(snapshot)=>{
            let code = "";
            let list = Object.keys(snapshot.val());
            do{
                code = "";
                for(var i = 0;i<4;i++){
                    code+=chars[Math.floor(Math.random()*36)];
                }
            }while(list.includes(code));
            let profane = false;
            let l = map["q"].split(" ");
            for(let j = 0; j<l.length;j++){
                profane = profanityList.includes(l[j].toLowerCase());
                if(profane){
                    break;
                }
            }
            if(!profane){
                outer: for(let j = 0; j<map["c"].length;j++){
                    let list = map["c"][j].split(" ");
                    for(let k = 0; k<list.length;k++){
                        profane = profanityList.includes(list[k].toLowerCase());
                        if(profane){
                            break outer;
                        }
                    }
                }
            }
            let returned = {
                "a":map["a"],
                "b":map["b"],
                "c":map["c"],
                "q":map["q"],
                "u":map["u"],
                "p":(profane?1:0),
                "t":Math.floor(Date.now()/1000)
            };
            return admin.database().ref("users/"+map["u"]+"/1").once("value",(snapshot)=>{
                let created = snapshot.val();
                if(created===null){
                    created = [];
                }
                created.push(code);
                admin.database().ref("users/"+map["u"]+"/1").set(created);
                admin.database().ref("data/"+code).set(returned);
                return res.send(JSON.stringify([code,returned]));
            });
        });
    }else{
        return res.send(JSON.stringify({"Error":"No Permissions"}));
    }
});