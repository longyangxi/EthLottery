pragma solidity ^0.4.19;
contract Owner{
  //拥有者
  address public owner;
  //构造器
  function Owner() public {
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
contract EwaLottery is Owner{
  bool public running = true;                                       //合同是否在运行 
  address[] public bettors;                                          //所有下注者地址

  address[] public luckyBettors;                                     //幸运奖者

  uint32 public minPlayers = 6;                                     //开奖基数，凑够多少人开奖
  uint public luckyFee = 1 finney;                                   //开小奖返还矿工费
  uint public baseBet =  5 finney;                                   //最少投注金额

  uint private _seed = 0;                                            //随机种子
    
  modifier limitValue(uint value){
    require(value >= baseBet);
    _;
  }
  modifier limitPause(){
    require(running);
    _;
  }
  //投注
  function Bet() limitValue(msg.value) payable limitPause external {
    //数组dai'lai带来 0.0008ETH的gas 
    bettors.push(msg.sender);
    //如果发送的超过基本投注记录余额
    uint remain = msg.value - baseBet;
    if(remain > 0) {
        // playerEthers[msg.sender] += remain;
        //多余的ehter直接返还 
        msg.sender.transfer(remain);
    }
    //检查小奖
    CheckLucky();
  }
  
  //设置合同暂停状态
  function SetPause(bool flag) onlyOwner external {
    running = flag;
  }
  //设置每人投资金额，单位分
  function SetMinBet(uint newBet) onlyOwner external {
      uint bet = newBet * 1 finney;
      baseBet = bet;
  }
  //设置抽奖人数基数
  function SetMinPlayers(uint32 min) onlyOwner external {
      require(min >= 2);
      minPlayers = min;
  }
    //小奖大小
  function GetLuckyValue() public view returns(uint) {
      //奖金为玩家数量 * 基础下注 - 矿工费
      return minPlayers * baseBet - luckyFee;
  }

  //查看人数是否够开小奖
  function IsLuckReady() private view returns (bool){
    return bettors.length >= (luckyBettors.length + 1) * minPlayers;
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
        msg.sender.transfer(luckyFee);
        return true;
    }

  //查看资金池
  function GetPool() public view returns(uint){
    return this.balance;
  }

    // return a pseudo random number between lower and upper bounds
  // given the number of previous blocks it should hash.
 function Random(uint upper) private returns (uint num) {
    _seed = uint(keccak256(keccak256(block.blockhash(block.number), _seed), now));
    return _seed % upper;
  }
}
