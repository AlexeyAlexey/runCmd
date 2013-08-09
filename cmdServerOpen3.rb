require 'socket'
require 'open3'
require 'open4'
#Synopsis https://github.com/djberg96/sys-proctable/wiki
require 'pp'
require 'sys/proctable'
include Sys
#Synopsis

class Cmd
  
  @@cmd_info = Hash.new
  
  def initialize(name, cmd)
    @cmd = cmd
    @name = name
    
    #@@cmd_info
    
    @pid = nil
    @inp = ""
    @out = ""
    @err = ""
    @name = ""
    @cmd_status = ""
    @group_pid = Array.new
  end
private  
  def group_pid()
    ppid = @pid
    
    @group_pid << @pid
    print "\n def group_pid() @pid = ", @pid,"\n"
    ProcTable.ps do |process|  
      (ppid = process.pid) if process.pid ==  ppid  
      (ppid = process.pid; @group_pid << ppid) if process.ppid == ppid
    end
    
    @group_pid
  end
  
  
  
public
  
  def cmdStart() 
    @inp, @out, @err, wait_thr = Open3.popen3(@cmd)
    @inp.close
    print "\nsinc out: ", @out.sync, ";\n"
    @out.sync = true
    print "\nsinc out: ", @out.sync, ";\n"
    @pid = wait_thr[:pid] #pid process 
    print "\nPID: ", @pid, ";\n"
      
    @thread = Thread.new do      
      begin
        
        while !(@out.eof?)
          Thread.current["out"] = "" if Thread.current["out"].nil?
          Thread.current["err"] = "" if Thread.current["err"].nil?
          out_st = @out.stat
          err_st = @err.stat
          print "\nblksiz out_st: ", out_st.blksize, "\n" 
          Thread.current["out"] += @out.read_nonblock out_st.blksize 
          Thread.current["err"] += @err.read_nonblock err_st.blksize 
          #Thread.stop
        end
        
      rescue IO::WaitReadable
        IO.select [@out]
        retry
      rescue EOFError
        Thread.current["out"] = "\nEOFError\n"
      end
    end
    
    print "\nEnd thread end method\n"
  end
  
  def inp
    @inp
  end
  
  def out
    begin
      @thread.run    
      @thread["out"]
    rescue ThreadError
      "empty"
    end
  end
  
  def err
    begin
      @thread.run
      @thread["err"]
    rescue ThreadError
      "empty"
    end
  end
  
  def cmdStatus()
    #http://manpages.ubuntu.com/manpages/lucid/man1/ps.1.html
    #PROCESS STATE CODES
    print "\ndef cmdStatus() @group_pid = ", @group_pid, ";\n" 
    group_pid if @group_pid.empty?
    
    print "\ncmdStatus @group_pid = ", @group_pid, "\n"
    status = ""
    state = Hash.new 
    @cmd_status = Hash.new
    
    print "\n@group_pid = ", @group_pid, "\n"
    @group_pid.each do |pid|
      print "\n@group_pid.each |#{pid}|; \n"
      ProcTable.ps do |process|  
        (state[pid] = process.state; print "\n state #{process.state}; \n") if process.pid ==  pid        
      end
    end
    print "\nstate = ", state, "\n"
    state.each do |pid, st|
      print "\nstate.each do |#{pid}, #{st}|\n"
      st.each_char do |char|
        print "\nst.each_char do |#{char}|\n"
        case char
          when "D"
            @cmd_status[pid] = "Uninterruptible sleep (usually IO)"
            status = "true"
            print "\nD\n"
          when "R"
            @cmd_status[pid] = "Running or runnable (on run queue)"
            status = "true"
            print "\nR\n"
          when "S"
            print "\nPID = ", pid, ";\n"
            @cmd_status[pid] = "Interruptible sleep (waiting for an event to complete)"
            status = "true"
            print "\nS\n"
          when "T"
            @cmd_status[pid] = "Stopped, either by a job control signal or because it is being traced."
            status = "true"
            print "\nT\n"
          when "W"
            @cmd_status[pid] = "paging (not valid since the 2.6.xx kernel)"
            status = "true"
          when "X"
            @cmd_status[pid] = "dead (should never be seen)"
            status = "false"
          when "Z"
            @cmd_status[pid] = " Defunct (zombie) process, terminated but not reaped by its parent."
            status = "false"
          when "<"
            @cmd_status[pid] += "; high-priority (not nice to other users)"
          when "N"
            @cmd_status[pid] += "; low-priority (nice to other users)"
          when "L"
            @cmd_status[pid] += "; has pages locked into memory (for real-time and custom IO)"
          when "s"
            @cmd_status[pid] += "; is a session leader"
          when "l"
            @cmd_status[pid] += "; is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)"
          when "+"
            @cmd_status[pid] += "; is in the foreground process group"
          
          else
          
        end
      end
    end
    @cmd_status
    status ||= "false"
  end
  
  
  def cmdStop() 
    
    @out.close
    @err.close
       
    puts group_pid ##creat group of PID @@group_pid
    group_pid.reverse_each do |pid|
      begin
        Process.kill("KILL", pid)
      rescue Errno::ESRCH
        print "\npid there is not #{pid}\n"
      end
    end
    
    @pid = nil
    @group_pid.clear
    #@thread["out"] = ""
  end

  
  
end


vpn = Cmd.new(:redcar, "sudo redcar")




server = TCPServer.open('localhost', 3001)

loop do
  client = server.accept
  puts client
  cmd, arg = client.gets.chomp.split
  #print "Gets: cmd: ", cmd, "; arg: ", arg;
  case cmd
    when "on"
      vpn.cmdStart      
    when "off"
      vpn.cmdStop      
    when "err"
      client.puts vpn.err
    when "out"
      client.puts vpn.out   
    when "status"
      client.puts vpn.cmdStatus   
    when "shutdown"
          client.close
    else
        
  end
  #print "Vpn.vpnStatus: ", Vpn.vpnStatus
  
  client.puts "endResponse"
  client.close  
end
