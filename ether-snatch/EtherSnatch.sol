pragma solidity ^0.5.0;

contract EtherSNATCH {
    /*
    Original game Adventureum 0x77b4acc38da51a0e77c77355cfd28c1a6619f6ba
    Original creator AnAllergyToAnalogy
    Modified by Econymous
    */

    //Gotta encode and decode the choice strings on the frontend
    event Situation(uint indexed id, string situationText, bytes32[] choiceTexts);

    //fromSituation    //choiceNum   //toSituation
    mapping(uint => mapping(uint => uint)) links;

    mapping(uint => uint) previousSituation; //backwards linklist

    //situation   //amount of gold to be mined
    mapping(uint => uint) public gold; //ETH that can be mined

    //situation    //number of choices
    mapping(uint => uint) options;

    //situation     //address that wrote it
    mapping(uint => address) authors;

    //author            //name
    mapping(address => string) signatures;

    //Earnings
    mapping(address => uint) earnings;

    //Total number of situations
    uint situationCount;
    //Un-closed pathways
    uint pathwayCount;

    //pushes the gold
    uint miningCart;


    constructor(string memory situationText, bytes32[] memory choiceTexts) public {

      require(choiceTexts.length > 0,"choices");

      //Define the option count
      options[0] = choiceTexts.length;

      //Set how many remaining open paths there are
      pathwayCount = choiceTexts.length;

      previousSituation[0] = 0;//this is just for earnings

      //Sign your name
      authors[0] = msg.sender;

      emit Situation(0,situationText,choiceTexts);
    }

    function add_situation(
        uint fromSituation,
        uint fromChoice,
        string memory situationText,
        bytes32[] memory choiceTexts) payable public{
        //Pay up
        require(msg.value == 5000000000000000, "pay up");

        //Make sure there is still at least one open pathway
        require(pathwayCount + choiceTexts.length > 1, "pathwayCount");

        //Make sure they didn't leave situationText blank
        require(bytes(situationText).length > 0,"situation");

        //Make sure this situation.choice actually exists
        require(fromChoice < options[fromSituation],"options");

        //Make sure this situation.choice hasn't been defined
        require(links[fromSituation][fromChoice] == 0,"choice");

        for(uint i = 0; i < choiceTexts.length; i++){
            require(choiceTexts[i].length > 0,"choiceLength");
        }

        //Increment situationCount, and this is the new situation num
        situationCount++;

        //Adjust pathwayCount
        pathwayCount += choiceTexts.length - 1;

        //Set pointer from previous situation
        links[fromSituation][fromChoice] = situationCount;
        //Set backwards pointer to previous situation
        previousSituation[situationCount] = fromSituation;

        //Set how many options there are for this situation
        options[situationCount] = choiceTexts.length;

        //Sign your name
        authors[situationCount] = msg.sender;

        //Pass earnings X steps where X = choiceTexts.length
        uint upperSituation = fromSituation;
        uint remainingEth = msg.value;
        uint reward;
        uint optionCount;
        for(uint i = 0; i<(choiceTexts.length-1); i++){
            optionCount = options[upperSituation];
            reward = 0;
            if(optionCount > 1){
                reward = remainingEth/optionCount;
                earnings[authors[upperSituation]] += reward;
            }
            remainingEth -= reward;
            upperSituation = previousSituation[upperSituation];
        }
        gold[upperSituation] += remainingEth;//this will be passed up later by miners

        emit Situation(situationCount,situationText,choiceTexts);
    }

    function pull_earnings() public{
      address wallet = msg.sender;
      require(earnings[wallet]>0,"What are you even trying to withdraw?");
      msg.sender.transfer( earnings[wallet] );
      earnings[wallet] = 0;
    }

    function see_gold(uint[] memory situations) public view returns(uint[] memory, uint[] memory){
      uint[] memory mineableGold = new uint[](situations.length);
      uint[] memory taxingDivision = new uint[](situations.length);
      for(uint i = 0; i<situations.length; i+=1){
        mineableGold[i] = gold[situations[i]];
        taxingDivision[i] = options[situations[i]];
      }
      return (mineableGold, taxingDivision);
    }

    function mine_gold(uint[] memory situations) public returns(uint){
      uint upperSituation;
      uint collectedGold = 0;
      uint upperOptionCount;
      uint writersReward;
      uint minersReward;
      uint goldToPassUp;
      uint i;
      for(i = 0; i<situations.length; i+=1){
        goldToPassUp = gold[situations[i]];
        if(goldToPassUp>0){
          gold[situations[i]] = 0;
          upperSituation = previousSituation[ situations[i] ];
          upperOptionCount = options[upperSituation];
          writersReward = 0;
          minersReward = 0;
          if(upperOptionCount>1){
            writersReward = goldToPassUp/upperOptionCount;
            goldToPassUp -= writersReward;
            earnings[authors[upperSituation]] += writersReward;
            minersReward = goldToPassUp/upperOptionCount;
          }
          gold[upperSituation] += goldToPassUp - minersReward;
          collectedGold += minersReward;
        }
      }

      for(i = 0; i<10; i+=1){
        goldToPassUp = gold[miningCart];
        if(goldToPassUp>0){
          gold[miningCart] = 0;
          upperSituation = previousSituation[ miningCart ];
          upperOptionCount = options[upperSituation];
          writersReward = 0;
          if(upperOptionCount>1){
            writersReward = goldToPassUp/upperOptionCount;
            goldToPassUp -= writersReward;
            earnings[authors[upperSituation]] += writersReward;
          }
          gold[upperSituation] += goldToPassUp;
        }

        if(miningCart==0){
          miningCart = situationCount;
        }else{
          miningCart -= 1;
        }
      }

      if(collectedGold>0){
        msg.sender.transfer(collectedGold);
      }
    }

    function add_signature(string memory signature) public{
        signatures[msg.sender] = signature;
    }

    function get_signature(uint situation) public view returns(string memory){
        return signatures[authors[situation]];
    }
    function get_author(uint situation) public view returns(address){
        return authors[situation];
    }

    function get_earnings(address author) public view returns(uint){
        return earnings[author];
    }

    function get_pathwayCount() public view returns(uint){
        return pathwayCount;
    }

    function get_next_situation(uint fromSituation, uint fromChoice) public view returns(uint,uint){
        uint situationID = links[fromSituation][fromChoice];
        return (situationID, gold[situationID]);
    }
}
