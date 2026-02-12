
lambda { |stdout,stderr,status|
  output = stdout + stderr
  return :green if /^.*Test execution complete\n.*test succeeded/.match(output)
  return :red   if /^.*Test execution complete\n.*test failed/.match(output)
  return :amber
}
