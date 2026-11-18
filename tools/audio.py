import sys, array
a = array.array('h', open(sys.argv[1], 'rb').read())
n = len(a)
print('peak', max(map(abs, a)) if n else 0, 'nonsilent_s', sum(1 for i in range(0, n, 800) if max(map(abs, a[i:i+800])) > 300) / 10)
