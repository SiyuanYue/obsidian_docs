命令	描述
tmux new-session	创建一个未命名的会话。可以简写为 tmux new 或者就一个简单的 tmux
tmux new -s development	创建一个名为 development 的会话
tmux new -s development -n editor	创建一个名为 development 的会话并把该会话的第一个窗口命名为 editor
tmux attach -t development	连接到一个名为 development 的会话
会话、窗口和面板的默认快捷键
快捷键	功能
PREFIX d	从一个会话中分离，让该会话在后台运行。
PREFIX :	进入命令模式
PREFIX c	在当前 tmux 会话创建一个新的窗口，是 new-window 命令的简写
PREFIX 0...9	根据窗口的编号选择窗口
PREFIX w	显示当前会话中所有窗口的可选择列表
PREFIX ,	显示一个提示符来重命名一个窗口
PREFIX &	杀死当前窗口，带有确认提示
PREFIX %	把当前窗口垂直地一分为二，分割后的两个面板各占 50% 大小
PREFIX "	把当前窗口水平地一分为二，分割后的两个面板各占 50% 大小
PREFIX o	在已打开的面板之间循环移动当前焦点
PREFIX q	短暂地显示每个面板的编号
PREFIX x	关闭当前面板，带有确认提示
PREFIX SPACE	循环地使用 tmux 的几个默认面板布局