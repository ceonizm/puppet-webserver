
Puppet::Functions.create_function(:'get_homedir') do
  dispatch :get_homedir do
    param 'String', :username
  end

  def get_homedir(username)
   begin
   result = Puppet::Util::Execution.execute(['/usr/bin/getent', 'passwd', username], {:failonfail=> true, :uid=> 0, :gid=>0})
   arr = result.split(':')
   arr[5]
   rescue Puppet::ExecutionFailure => e
    result = ""
    result
   end
  end
end
