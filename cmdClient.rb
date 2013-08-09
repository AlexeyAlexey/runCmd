require 'socket'

s = TCPSocket.open('localhost', 3001)

 print "\nEntry command: " 
 cmd = gets.chomp
 print "cmd: ", cmd, "\n"
 s.puts cmd

 while line = s.gets 
   puts line.chop
 end

 

s.close