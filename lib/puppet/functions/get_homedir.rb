
Puppet::Functions.create_function(:'get_homedir') do
  dispatch :get_homedir do
    param 'String', :username
  end

  def get_homedir(username)
   result = Puppet::Util::Execution.execute(['/usr/bin/getent', 'passwd', username], {:failonfail=> true, :uid=> 0, :gid=>0})
   arr = result.split(':')
   arr[5]
#     result = Puppet::Util::Execution.execute(['whoami'], {:failonfail=> true, :uid=> 0, :gid=>0})
  end
end
