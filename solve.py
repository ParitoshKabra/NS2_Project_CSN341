# Using readlines()
file1 = open('simple.tr', 'r')
Lines = file1.readlines()
  
count = 0
map3 = {}
map = {}
map2 = {}
count = 0
# Strips the newline character
for line in Lines:
    # if count>100 :
    #   break
    count +=1 
    z= line.strip()
    arr = z.split(" ")
    # print(arr)
    # print(type(arr[-1]))
    if arr[0]=='+' and arr[4] == "tcp" :
      if arr[2]=='1':
        if arr[3]=='4':
          if (3,4) not in map:
            map[1,4] = float(arr[1])
          else : 
            map[1,4] +=float(arr[1])
      if arr[2]=='2':
        if arr[3]=='4':
          if (2,4) not in map:
            map[2,4] = float(arr[1])
          else : 
            map[2,4]+=float(arr[1])
      if arr[2]=='3':
        if arr[3]=='4':
          if (3,4) not in map:
            map[3,4] = float(arr[1])
          else :
            map[3,4]+=float(arr[1])
      if arr[2]=='0':
        if arr[3]=='4':
          if (0,4) not in map:
            map[0,4] = float(arr[1])
          else: 
            map[0,4]+= float(arr[1])
           

    if arr[0]=='r' and arr[4]=="ack":
      if arr[2]=='4':
        if arr[3]=='1':
          count+=1
          if (1,4)  in map and (1,4) not in map2:
            map2[1,4] = float(arr[1])
          elif (1,4)  in map and (1,4) in map2: 
            map2[1,4]+= float(arr[1])
      if arr[2]=='4':
        if arr[3]=='2':
          count+=1
          if (2,4) in map and (2,4) not in map2:
            map2[2,4] = float(arr[1])
          elif (2,4)  in map and (2,4) in map2: 
            map2[2,4]+= float(arr[1])
      if arr[2]=='4':
        if arr[3]=='3':
          count+=1
          if (3,4) in map and (3,4) not in map2:
            map2[3,4] = float(arr[1])
          elif (3,4)  in map and (3,4) in map2:
            map2[3,4]+= float(arr[1])
      if arr[2]=='4':
        if arr[3]=='0':
          count+=1
          if (0,4) in map and (3,4) not in map2:
            map2[(0,4)] = float(arr[1])
          elif (0,4)  in map and (0,4) in map2:
            map2[0,4]+= float(arr[1])
print(map)
print(count)
print(map2)
a1 = (map2[0,4] - map[0,4])/count
a2 = (map2[1,4] - map[1,4])/count
a3 = (map2[2,4] - map[2,4])/count
a4 = (map2[3,4] - map[3,4])/count
print(abs(a1),abs(a2),abs(a3),abs(a4))
