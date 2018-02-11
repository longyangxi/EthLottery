pragma solidity ^0.4.19;
contract Owner{
  //拥有者
  address public owner;
  //构造器
  function Owner() {
      owner = msg.sender;
  }
  //函数修饰符 限定创建者调用
  modifier onlyOwner{
    require(msg.sender == owner);
    _;
  }
  //转手合同
  function transferOwnership(address newOwner) public onlyOwner{
    if(newOwner!=address(0)){
      owner = newOwner;
    }
  }
}
//投资合同
contract EthLottery is Owner{

  address[] public bettors;                                          //所有下注者地址

  address[] public luckyBettors;                                     //幸运奖者
  address[] public bigLuckyBettors;                                  //幸运大奖者

  uint32 public minPlayers = 10;                                     //开奖基数，凑够多少人开奖
  uint[] public lotteryCountHistory;                                 //开大奖中间开过的小奖励次数
  
  uint public baseBet = 10 finney;                                   //最少投注金额
  uint public poolExtract = 10 finney;                               //每次开奖奖池抽取
  uint public bigLuckyValue = 200 finney;                             //大奖奖励数量
  uint public bigLuckyPlayers = 5;                                   //大奖奖励玩家数量
  
  
  uint private _seed = 0;                                            //随机种子

  modifier limitAmount(uint value){
    require(value >= baseBet);
    _;
  }

  //投注
  function Bet() limitAmount(msg.value) payable external {
    bettors.push(msg.sender);
    
    //检查小奖
    if(!CheckLucky()) {
        //小奖没有则检查大奖
        CheckBigLucky();
    }
  }

  //设置每人投资金额
  function SetMinBet(uint newBet) onlyOwner external {
      baseBet = newBet;
  }
  //设置每次开奖金额
  function SetPoolExtract(uint extract) onlyOwner external {
      poolExtract = extract;
  }
  //设置大奖金额
  function SetBigLuckyValue(uint bigValue) onlyOwner external {
      bigLuckyValue = bigValue;
  }
    //设置大奖人数
  function SetBigLuckyPlayers(uint players) onlyOwner external {
      bigLuckyPlayers = players;
  }
  //设置抽奖人数基数
  function SetMinPlayers(uint32 min) onlyOwner external {
      minPlayers = min;
  }

    //小奖大小
  function GetLuckyValue() public view returns(uint) {
      //奖金为玩家数量 * 基础下注 - 奖池抽取
      return minPlayers * baseBet - poolExtract;
  }

  //查看人数是否够开小奖
  function IsLuckReady() public view returns (bool){
    return bettors.length >= (luckyBettors.length + 1) * minPlayers;
  }

  //是否可开大奖,考虑40+9的情况，最后必须保证余额要多于最后9人的下注额度
  function IsBigLuckyReady() public view returns(bool) {
      return this.balance > bigLuckyValue * bigLuckyPlayers + baseBet * minPlayers;
  }

  //返回总的投资次数
  function TotalBetters() external view returns (uint) {
      return bettors.length;
  }

  //总的小奖开奖次数
  function TotalLottery() external view returns(uint) {
      return luckyBettors.length;
  }

  //返回某玩家的投注历史
  function BetsOfPlayer(address _player) external view returns(uint[] bets) {
    uint total = bettors.length;
    if (total == 0) {
        return new uint[](0);
    } else {
        uint[] memory result = new uint[](total);

        uint resultIndex = 0;
        uint theId;
        for (theId = 0; theId < total; theId++) {
            if (bettors[theId] == _player) {
                result[resultIndex] = theId;
                resultIndex++;
            }
        }
        uint[] memory resultTemp = new uint[](resultIndex);
        for(theId = 0; theId < resultIndex; theId++){
          resultTemp[theId] = result[theId];
        }
        return resultTemp;
    }
  }
    //检查小奖
    function CheckLucky() private returns(bool) {
        //是否满足条件
        if(!IsLuckReady()) return false;

        uint lotteryIndex = luckyBettors.length;
        
        uint winnerIndex = Random(minPlayers);
        winnerIndex = lotteryIndex * minPlayers + winnerIndex;
        address winner = bettors[winnerIndex];
        
        uint luckyValue = GetLuckyValue();
        //发放奖金
        if(this.balance > luckyValue) {
            winner.transfer(luckyValue);
        }
        
        luckyBettors.push(winner);
        
        return true;
    }

  //检查是否可发大奖
  function CheckBigLucky() private returns(bool) {
    //需要满足大奖条件
    if(!IsBigLuckyReady()) return false;

    uint oldIndex = 0;
    uint bigLuckyIndex = lotteryCountHistory.length;
    uint lotteryIndex = luckyBettors.length;
    //获取所有阶段全部开过奖的次数
    for(uint i = 0; i < bigLuckyIndex; i++)
      oldIndex += lotteryCountHistory[bigLuckyIndex];
    //计算需要开奖的基数(开奖次数)
    uint num = lotteryIndex - oldIndex;
    for( i = 0; i < bigLuckyPlayers;i++){
      uint index = Random(num * minPlayers);
      address winner = bettors[index + oldIndex * minPlayers];
      bigLuckyBettors.push(winner);
      //赢者发奖金
      winner.transfer(bigLuckyValue);
    }
    lotteryCountHistory.push(num);
    return true;
  }

  //查看资金池
  function GetAwardPool() public view returns(uint){
    return this.balance;
  }

    // return a pseudo random number between lower and upper bounds
  // given the number of previous blocks it should hash.
 function Random(uint upper) private returns (uint num) {
    _seed = uint(keccak256(keccak256(block.blockhash(block.number), _seed), now));
    return _seed % upper;
  }
}
