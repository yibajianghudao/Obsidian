import pandas as pd
from pypinyin import pinyin, Style
import chardet
def readXlsx(filename, sheetName, cloumName1, cloumName2):
    data = pd.DataFrame(pd.read_excel(filename, sheet_name=sheetName, usecols=[cloumName1, cloumName2]))
    data_list = data.values.tolist()
    return data_list

def mkConf(confName, data):
    with open(confName, 'w', encoding='utf-8') as f:
        for li in data:
            line = f"++ {str_to_pinyin(li[0])}\nmenu = {li[0]}\ntitle = {li[1]}\nhost = {li[1]}\n"
            f.write(line)

def mkConfWithTitle(confName, data:dict, titleId, menu, titleOne):
    with open(confName, 'w', encoding='utf-8') as f:
        # 一级标题
        titleC = f"+ {titleId}\n\nmenu = {menu}\ntitle = {titleOne}\n\n"
        f.write(titleC)
        # 二级标题
        for d in data.keys():
            d_pinyin = str_to_pinyin(d)
            # 循环一遍label,组装host
            host = ""
            for li in data[d]:
                l_pinyin = str_to_pinyin(li[0])
                h = f"/{titleId}/{d_pinyin}/{l_pinyin} "
                host += h 
            title = f"++ {d_pinyin}\nmenu = {d}\ntitle = {d}节点网络监控列表\nhost = {host}\n\n"
            f.write(title)
            # 三级
            for li in data[d]:
                line = f"+++ {str_to_pinyin(li[0])}\nmenu = {li[0]}\ntitle = {li[0]}\nhost = {li[1]}\n\n"
                f.write(line)


def str_to_pinyin(text):
    try:
        # 将每个汉字转换为拼音，非汉字字符保留原样
        pinyin_list = pinyin(text, style=Style.NORMAL)
        # 将拼音列表连接成字符串
        result = ''.join([item[0] for item in pinyin_list])
        return result
    except Exception as e:
        print(f"转换出错: {e}")
        return text

def SelectWithTitle(titleList, data, trash):
    dataWithTitle = {}
    for title in titleList:
        dataWithTitle[title] = []
    dataWithTitle[trash] = []
    for d in data:
        repeat = False
        have = False
        for title in titleList:
            # 重复匹配标签
            if repeat and title in d[0]:
                # 删除上一个标签最新数据
                dataWithTitle[titleList[titleList.index(title)-1]].pop()
                # 在trash标签
                dataWithTitle[trash].append(d)
                have = True
                break
            elif title in d[0]:
                dataWithTitle[title].append(d)
                repeat = True
                have = True
        if not have:
            dataWithTitle[trash].append(d)
    # print(dataWithTitle)
    return dataWithTitle
if __name__ == "__main__":
    filename = "./42.225.98.34-ping-result.xlsx"
    sheetName = "page1"
    cloumName1 = "探测点"
    cloumName2 = "探测源IP"
    data = readXlsx(filename=filename, sheetName=sheetName, cloumName1=cloumName1, cloumName2=cloumName2)

    ## 打印所有节点的配置
    # confName = "smokeping"
    # mkConf(confName=confName, data=data)

    # 类别标签,配置以拼音为内部标识符,标签的拼音不能相同
    titleList = ['电信','联通','移动','阿里巴巴']
    # 如果匹配重复的类别或没有匹配到任何类别,则放在trash类别下
    trash = "其它"
    # 匹配类别
    dataWithTitle = SelectWithTitle(titleList=titleList, data=data, trash=trash)
    
    # 分类打印
    titleConfName = "titleconf"
    titleId = "Other"
    menu = "移动,联通,电信,阿里巴巴网络监控"
    titleOne = "监控统计"
    mkConfWithTitle(confName=titleConfName, data=dataWithTitle, titleId=titleId, menu=menu, titleOne=titleOne)

