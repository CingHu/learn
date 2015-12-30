import re, sys, collections, operator

# tcpdump -lnni eth3 'ip and not arp' -c 10000

prog = re.compile('(\d+.\d+.\d+.\d+)(.\d+)? > (\d+.\d+.\d+.\d+)(.\d+)?')

stats = []
for i in range(4):
    stats.append(collections.defaultdict(int))

for line in sys.stdin:
    result = prog.search(line)
    if result:
        for i in range(4):
            stats[i][result.group(i+1)] += 1

for stat, desc in zip(stats, ('src', 'sport', 'dst', 'dport')):
    rank = sorted(stat.items(),key=operator.itemgetter(1), reverse=True)
    print desc
    print rank[:10]
