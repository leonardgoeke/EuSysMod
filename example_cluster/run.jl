using Distributed

f = open("machinefile.txt", "r")
for line in readlines(f)
    node, cores, queue, undefined = split(line, " ")
    println("Adding node $node with $cores workers")
    addprocs([(node, parse(Int,cores))])
end
close(f)

for w in workers()
    @spawnat w println(myid())
    @spawnat w run(`hostname`)
end


