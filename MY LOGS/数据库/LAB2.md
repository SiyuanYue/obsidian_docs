


# 1. 选题：
酒店 （*酒店代码*，酒店名称 , 酒店地址, 酒店星级，酒店电话，**酒店所属岛屿代码**）
酒店经理 （*身份证号*，姓名，电话）
房间 （*房间号，所属酒店代码*，容纳人数，价格，设施物品）
岛屿 （*岛屿代码*，岛屿名称，岛屿分级，岛屿信息）
餐厅 （*餐厅代码*，餐厅地址，平均消费，餐厅名称，**餐厅所属岛屿代码**）
景点 （名称，*景点代码*，地址，开放时间，门票价格，**所属岛屿代码**)
游客 （游客名，*游客身份证号* ，电话）
轮船班次（*班次号*，出发时间，到达时间，价格，**目的岛屿代码**）

联系：
酒店和岛屿构成 “酒店位于”的联系, n:1
酒店和房间 “包含”的联系 1：n
餐厅和岛屿构成 “餐厅位于”的联系，n:1
景点和岛屿构成 “景点位于”的联系，n:1
游客和轮船班次构成“乘坐”的联系，n:1
酒店经理和酒店构成“管理”的联系， 1:1
游客和房间构成“居住”的联系，n:1
游客和景点构成“游玩”的联系，n:m
游客和餐厅构成“就餐”的联系，n:m
轮船班次和岛屿构成“到达”的联系，n:1
# 2 绘制E-R 图
![[数据库实验二.jpg]]

# 3. 设计逻辑数据库
ISLAND_TRAVEL
岛屿 （*岛屿代码*  I#，岛屿名称 Iname，岛屿分级 Ilevel，岛屿信息 Imessage）
酒店经理 （*身份证号* ID，姓名 HMname ，电话 HMphone，**酒店代码** H#）
酒店 （*酒店代码* H#，酒店名称 Hname , 酒店地址 Haddress, 酒店星级 Hstar，酒店电话 Hphone，**酒店所属岛屿代码** I#）
房间 （*房间号* N#，*所属酒店代码* H#，容纳人数 Capacity，价格 Nprice，设施物品Article）
房间是酒店的弱实体
餐厅 （*餐厅代码* C#，餐厅地址 CAddress，~~平均消费~~，餐厅名称 CNAME，**餐厅所属岛屿代码** I#）
景点 （名称 Vname，*景点代码* V#，地址 Vaddress，开放时间 Vtime，门票价格 Vprice，**所属岛屿代码** I#)
游客 （游客名 Tname，*游客身份证号* ID，电话 Tphone，**乘坐班次号** A# ）
居住 （~~*编号* ~~，*房间号 N#, 所属酒店代码 H#，游客身份证号 ID*，起始居住日期 Sdate，结束居住日期 Edate）
就餐 （~~*编号*~~，*游客身份证号 ID，餐厅代码* C#，时间 Ctime，消费价格 Cprice）
游玩 （~~*编号*~~，*游客身份证号 ID，景点代码*V#，时间 Vtime，游玩满意度 Vscore）
轮船班次（*班次号* A#，出发时间 Stime，到达时间 Etime，价格 Aprice，**目的岛屿代码** I#）




