#!/usr/bin/env python3
"""픽셀 아트 테마 생성기.

Noto Color Emoji(OFL 1.1) 글리프를 저해상도 격자로 줄이고 색상을 양자화해서
assets/art/themes.json 을 만듭니다.

사용법: python3 tool/gen_art.py [--sheet out.png]
"""
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf'
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'art' / 'themes.json'

CATS = [
    ('fruit', '과일', 'Fruits'),
    ('veggie', '채소', 'Veggies'),
    ('meal', '식사', 'Meals'),
    ('sweet', '디저트', 'Sweets'),
    ('drink', '음료', 'Drinks'),
    ('animal', '동물', 'Animals'),
    ('bird', '새', 'Birds'),
    ('sea', '바다', 'Ocean'),
    ('bug', '곤충', 'Bugs'),
    ('plant', '식물', 'Plants'),
    ('vehicle', '탈것', 'Vehicles'),
    ('sport', '스포츠', 'Sports'),
    ('art', '음악·예술', 'Music & Art'),
    ('sky', '하늘·우주', 'Sky & Space'),
    ('object', '물건', 'Objects'),
    ('fantasy', '판타지', 'Fantasy'),
    ('party', '축제', 'Festive'),
    ('place', '건물', 'Places'),
    ('face', '표정', 'Faces'),
    ('wear', '패션', 'Fashion'),
]

T = {
    'fruit': [('🍎', '사과', 'Apple'), ('🍊', '귤', 'Tangerine'), ('🍋', '레몬', 'Lemon'), ('🍌', '바나나', 'Banana'),
              ('🍉', '수박', 'Watermelon'), ('🍇', '포도', 'Grapes'), ('🍓', '딸기', 'Strawberry'), ('🍒', '체리', 'Cherries'),
              ('🍑', '복숭아', 'Peach'), ('🍍', '파인애플', 'Pineapple'), ('🥝', '키위', 'Kiwi'), ('🍐', '배', 'Pear'),
              ('🍏', '풋사과', 'Green Apple'), ('🥭', '망고', 'Mango'), ('🥥', '코코넛', 'Coconut'), ('🍈', '멜론', 'Melon'),
              ('🫐', '블루베리', 'Blueberries')],
    'veggie': [('🥕', '당근', 'Carrot'), ('🌽', '옥수수', 'Corn'), ('🍅', '토마토', 'Tomato'), ('🍆', '가지', 'Eggplant'),
               ('🥦', '브로콜리', 'Broccoli'), ('🌶️', '고추', 'Chili'), ('🥑', '아보카도', 'Avocado'), ('🍄', '버섯', 'Mushroom'),
               ('🥔', '감자', 'Potato'), ('🧄', '마늘', 'Garlic'), ('🧅', '양파', 'Onion'), ('🥒', '오이', 'Cucumber'),
               ('🫑', '피망', 'Bell Pepper'), ('🥬', '배추', 'Leafy Green'), ('🍠', '군고구마', 'Sweet Potato'), ('🌰', '밤', 'Chestnut'),
               ('🥜', '땅콩', 'Peanuts')],
    'meal': [('🍔', '햄버거', 'Burger'), ('🍕', '피자', 'Pizza'), ('🌭', '핫도그', 'Hot Dog'), ('🍟', '감자튀김', 'Fries'),
             ('🌮', '타코', 'Taco'), ('🍣', '초밥', 'Sushi'), ('🍙', '주먹밥', 'Rice Ball'), ('🍜', '라면', 'Ramen'),
             ('🍳', '계란프라이', 'Fried Egg'), ('🥪', '샌드위치', 'Sandwich'), ('🍗', '닭다리', 'Drumstick'), ('🍖', '만화고기', 'Meat'),
             ('🥓', '베이컨', 'Bacon'), ('🍤', '새우튀김', 'Fried Shrimp'), ('🍱', '도시락', 'Bento'), ('🍛', '카레', 'Curry'),
             ('🥐', '크루아상', 'Croissant'), ('🥨', '프레첼', 'Pretzel'), ('🧀', '치즈', 'Cheese'), ('🥞', '팬케이크', 'Pancakes'),
             ('🧇', '와플', 'Waffle'), ('🍞', '식빵', 'Bread'), ('🥖', '바게트', 'Baguette'), ('🌯', '부리토', 'Burrito'),
             ('🍝', '스파게티', 'Spaghetti'), ('🥟', '만두', 'Dumpling'), ('🍚', '쌀밥', 'Rice'), ('🥗', '샐러드', 'Salad'),
             ('🍲', '전골', 'Stew'), ('🥚', '달걀', 'Egg'), ('🥩', '스테이크', 'Steak'), ('🥯', '베이글', 'Bagel')],
    'sweet': [('🍩', '도넛', 'Donut'), ('🍪', '쿠키', 'Cookie'), ('🎂', '생일케이크', 'Birthday Cake'), ('🍰', '조각케이크', 'Shortcake'),
              ('🧁', '컵케이크', 'Cupcake'), ('🍫', '초콜릿', 'Chocolate'), ('🍬', '사탕', 'Candy'), ('🍭', '막대사탕', 'Lollipop'),
              ('🍮', '푸딩', 'Pudding'), ('🍦', '소프트아이스크림', 'Soft Serve'), ('🍨', '아이스크림', 'Ice Cream'), ('🍧', '빙수', 'Shaved Ice'),
              ('🍡', '당고', 'Dango'), ('🥧', '파이', 'Pie'), ('🍯', '꿀단지', 'Honey Pot'), ('🍿', '팝콘', 'Popcorn'),
              ('🥮', '월병', 'Moon Cake'), ('🍘', '센베이', 'Rice Cracker'), ('🥠', '포춘쿠키', 'Fortune Cookie')],
    'drink': [('☕', '커피', 'Coffee'), ('🍵', '녹차', 'Green Tea'), ('🧋', '버블티', 'Bubble Tea'), ('🥤', '탄산음료', 'Soda'),
              ('🧃', '주스팩', 'Juice Box'), ('🥛', '우유', 'Milk'), ('🍹', '트로피컬', 'Tropical Drink'), ('🍼', '젖병', 'Baby Bottle'),
              ('🫖', '찻주전자', 'Teapot'), ('🧉', '마테차', 'Mate'), ('🥫', '통조림', 'Canned Food'), ('🧊', '얼음', 'Ice Cube')],
    'animal': [('🐶', '강아지', 'Puppy'), ('🐱', '고양이', 'Cat'), ('🐭', '생쥐', 'Mouse'), ('🐹', '햄스터', 'Hamster'),
               ('🐰', '토끼', 'Bunny'), ('🦊', '여우', 'Fox'), ('🐻', '곰', 'Bear'), ('🐼', '판다', 'Panda'),
               ('🐨', '코알라', 'Koala'), ('🐯', '호랑이', 'Tiger'), ('🦁', '사자', 'Lion'), ('🐮', '젖소', 'Cow'),
               ('🐷', '돼지', 'Pig'), ('🐸', '개구리', 'Frog'), ('🐵', '원숭이', 'Monkey'), ('🦄', '유니콘', 'Unicorn'),
               ('🐢', '거북이', 'Turtle'), ('🐍', '뱀', 'Snake'), ('🦖', '티라노', 'T-Rex'), ('🦕', '공룡', 'Dinosaur'),
               ('🐘', '코끼리', 'Elephant'), ('🦒', '기린', 'Giraffe'), ('🦓', '얼룩말', 'Zebra'), ('🐪', '낙타', 'Camel'),
               ('🦘', '캥거루', 'Kangaroo'), ('🦔', '고슴도치', 'Hedgehog'), ('🐿️', '다람쥐', 'Chipmunk'), ('🦝', '너구리', 'Raccoon'),
               ('🐺', '늑대', 'Wolf'), ('🐗', '멧돼지', 'Boar'), ('🐴', '말', 'Horse'), ('🦥', '나무늘보', 'Sloth'),
               ('🐊', '악어', 'Crocodile'), ('🦛', '하마', 'Hippo'), ('🦏', '코뿔소', 'Rhino'), ('🐑', '양', 'Sheep')],
    'bird': [('🐔', '닭', 'Chicken'), ('🐧', '펭귄', 'Penguin'), ('🐤', '병아리', 'Chick'), ('🦆', '오리', 'Duck'),
             ('🦉', '부엉이', 'Owl'), ('🦜', '앵무새', 'Parrot'), ('🦩', '플라밍고', 'Flamingo'), ('🦚', '공작', 'Peacock'),
             ('🦅', '독수리', 'Eagle'), ('🦃', '칠면조', 'Turkey'), ('🦢', '백조', 'Swan'), ('🐦', '파랑새', 'Bird'),
             ('🐣', '알깐 병아리', 'Hatching Chick'), ('🦇', '박쥐', 'Bat')],
    'sea': [('🐟', '물고기', 'Fish'), ('🐠', '열대어', 'Tropical Fish'), ('🐡', '복어', 'Blowfish'), ('🦈', '상어', 'Shark'),
            ('🐙', '문어', 'Octopus'), ('🦀', '게', 'Crab'), ('🦞', '바닷가재', 'Lobster'), ('🦐', '새우', 'Shrimp'),
            ('🦑', '오징어', 'Squid'), ('🐳', '고래', 'Whale'), ('🐬', '돌고래', 'Dolphin'), ('🐚', '소라', 'Seashell'),
            ('🦭', '물개', 'Seal'), ('🪸', '산호', 'Coral'), ('🐋', '흰긴수염고래', 'Blue Whale'), ('🦦', '수달', 'Otter')],
    'bug': [('🐝', '꿀벌', 'Bee'), ('🐞', '무당벌레', 'Ladybug'), ('🦋', '나비', 'Butterfly'), ('🐛', '애벌레', 'Caterpillar'),
            ('🐌', '달팽이', 'Snail'), ('🐜', '개미', 'Ant'), ('🕷️', '거미', 'Spider'), ('🦂', '전갈', 'Scorpion'),
            ('🪲', '딱정벌레', 'Beetle'), ('🦗', '귀뚜라미', 'Cricket')],
    'plant': [('🌵', '선인장', 'Cactus'), ('🌴', '야자수', 'Palm Tree'), ('🌲', '소나무', 'Pine Tree'), ('🌳', '나무', 'Tree'),
              ('🌻', '해바라기', 'Sunflower'), ('🌷', '튤립', 'Tulip'), ('🌹', '장미', 'Rose'), ('🌸', '벚꽃', 'Cherry Blossom'),
              ('🌺', '히비스커스', 'Hibiscus'), ('🍀', '네잎클로버', 'Clover'), ('🍁', '단풍잎', 'Maple Leaf'), ('🌼', '들꽃', 'Blossom'),
              ('🪴', '화분', 'Potted Plant'), ('💐', '꽃다발', 'Bouquet'), ('🌱', '새싹', 'Sprout'), ('🪷', '연꽃', 'Lotus')],
    'vehicle': [('🚗', '자동차', 'Car'), ('🚕', '택시', 'Taxi'), ('🚌', '버스', 'Bus'), ('🚓', '경찰차', 'Police Car'),
                ('🚑', '구급차', 'Ambulance'), ('🚒', '소방차', 'Fire Truck'), ('🚜', '트랙터', 'Tractor'), ('🚲', '자전거', 'Bicycle'),
                ('🛵', '스쿠터', 'Scooter'), ('🚂', '기관차', 'Locomotive'), ('✈️', '비행기', 'Airplane'), ('🚀', '로켓', 'Rocket'),
                ('🚁', '헬리콥터', 'Helicopter'), ('⛵', '돛단배', 'Sailboat'), ('🚢', '여객선', 'Ship'), ('🛸', 'UFO', 'UFO'),
                ('🚚', '트럭', 'Truck'), ('🏎️', '경주차', 'Race Car'), ('🛶', '카누', 'Canoe'), ('🚤', '보트', 'Speedboat'),
                ('🎈', '풍선', 'Balloon'), ('🛹', '스케이트보드', 'Skateboard')],
    'sport': [('⚽', '축구공', 'Soccer Ball'), ('🏀', '농구공', 'Basketball'), ('🏈', '미식축구', 'Football'), ('⚾', '야구공', 'Baseball'),
              ('🎾', '테니스공', 'Tennis Ball'), ('🏐', '배구공', 'Volleyball'), ('🎱', '당구공', '8 Ball'), ('🏓', '탁구', 'Ping Pong'),
              ('🥊', '권투글러브', 'Boxing Glove'), ('🏆', '트로피', 'Trophy'), ('🥇', '금메달', 'Gold Medal'), ('🎯', '다트', 'Bullseye'),
              ('🎳', '볼링', 'Bowling'), ('⛸️', '스케이트', 'Ice Skate'), ('🏸', '배드민턴', 'Badminton'), ('🛼', '롤러스케이트', 'Roller Skate')],
    'art': [('🎸', '기타', 'Guitar'), ('🎹', '건반', 'Keyboard'), ('🥁', '드럼', 'Drum'), ('🎺', '트럼펫', 'Trumpet'),
            ('🎻', '바이올린', 'Violin'), ('🎷', '색소폰', 'Saxophone'), ('🎨', '팔레트', 'Palette'), ('🎭', '가면', 'Masks'),
            ('🎬', '슬레이트', 'Clapperboard'), ('🎧', '헤드폰', 'Headphones'), ('🎤', '마이크', 'Microphone'), ('📷', '카메라', 'Camera'),
            ('🎮', '게임패드', 'Gamepad'), ('🎲', '주사위', 'Dice'), ('🧩', '퍼즐', 'Puzzle Piece'), ('🪀', '요요', 'Yo-Yo'),
            ('🪁', '연', 'Kite'), ('🧸', '곰인형', 'Teddy Bear')],
    'sky': [('🌞', '해님', 'Sun'), ('🌙', '초승달', 'Moon'), ('⭐', '별', 'Star'), ('🌈', '무지개', 'Rainbow'),
            ('⛅', '구름과 해', 'Sun & Cloud'), ('⚡', '번개', 'Lightning'), ('🔥', '불꽃', 'Fire'), ('💧', '물방울', 'Droplet'),
            ('🌍', '지구', 'Earth'), ('🪐', '토성', 'Saturn'), ('☄️', '혜성', 'Comet'), ('⛄', '눈사람', 'Snowman'),
            ('🌋', '화산', 'Volcano'), ('🌊', '파도', 'Wave'), ('🌝', '보름달', 'Full Moon'), ('☂️', '우산', 'Umbrella')],
    'object': [('💡', '전구', 'Light Bulb'), ('🔑', '열쇠', 'Key'), ('🔔', '종', 'Bell'), ('📚', '책', 'Books'),
               ('✏️', '연필', 'Pencil'), ('✂️', '가위', 'Scissors'), ('⏰', '알람시계', 'Alarm Clock'), ('🧲', '자석', 'Magnet'),
               ('🔨', '망치', 'Hammer'), ('🧯', '소화기', 'Extinguisher'), ('🪣', '양동이', 'Bucket'), ('🧺', '바구니', 'Basket'),
               ('💎', '보석', 'Gem'), ('💰', '돈주머니', 'Money Bag'), ('📺', '텔레비전', 'TV'), ('☎️', '전화기', 'Telephone'),
               ('🔋', '배터리', 'Battery'), ('🧪', '시험관', 'Test Tube'), ('🔭', '망원경', 'Telescope'), ('🪑', '의자', 'Chair'),
               ('🕯️', '양초', 'Candle'), ('📌', '압정', 'Pushpin'), ('🧨', '폭죽', 'Firecracker'), ('🪙', '동전', 'Coin')],
    'fantasy': [('👻', '유령', 'Ghost'), ('👽', '외계인', 'Alien'), ('🤖', '로봇', 'Robot'), ('👾', '몬스터', 'Space Invader'),
                ('🐉', '용', 'Dragon'), ('🧙', '마법사', 'Wizard'), ('🧚', '요정', 'Fairy'), ('🧜', '인어', 'Merperson'),
                ('👑', '왕관', 'Crown'), ('🔮', '수정구슬', 'Crystal Ball'), ('🗡️', '단검', 'Dagger'), ('🛡️', '방패', 'Shield'),
                ('🏰', '성', 'Castle'), ('🧞', '지니', 'Genie'), ('💀', '해골', 'Skull'), ('👹', '도깨비', 'Ogre'),
                ('🪄', '요술봉', 'Magic Wand'), ('🧛', '뱀파이어', 'Vampire')],
    'party': [('🎃', '호박등', 'Jack-o-Lantern'), ('🎄', '크리스마스트리', 'Xmas Tree'), ('🎅', '산타', 'Santa'), ('🎁', '선물', 'Gift'),
              ('🎉', '폭죽', 'Party Popper'), ('🪅', '피냐타', 'Piñata'), ('🎀', '리본', 'Ribbon'), ('🎏', '잉어깃발', 'Carp Streamer'),
              ('🏮', '홍등', 'Lantern'), ('🎎', '인형', 'Dolls'), ('🧧', '세뱃돈', 'Red Envelope'), ('🎠', '회전목마', 'Carousel'),
              ('🎡', '관람차', 'Ferris Wheel'), ('🎪', '서커스', 'Circus Tent'), ('💝', '하트선물', 'Heart Gift'), ('❤️', '하트', 'Heart'),
              ('🦌', '루돌프', 'Reindeer'), ('🔔', '방울', 'Jingle Bell')],
    'place': [('🏠', '집', 'House'), ('🏥', '병원', 'Hospital'), ('🏫', '학교', 'School'), ('⛪', '교회', 'Church'),
              ('🏯', '일본성', 'Japanese Castle'), ('🗼', '타워', 'Tower'), ('🗽', '자유의 여신상', 'Liberty'), ('⛺', '텐트', 'Tent'),
              ('🏝️', '무인도', 'Island'), ('⛲', '분수', 'Fountain'), ('🏪', '편의점', 'Store'), ('🗿', '모아이', 'Moai'),
              ('🏭', '공장', 'Factory'), ('⛩️', '도리이', 'Shrine')],
    'face': [('😀', '웃음', 'Grin'), ('😎', '선글라스', 'Cool'), ('😍', '하트눈', 'Heart Eyes'), ('🤩', '별눈', 'Star-Struck'),
             ('😴', '쿨쿨', 'Sleepy'), ('🤠', '카우보이', 'Cowboy'), ('🥳', '파티', 'Partying'), ('😭', '엉엉', 'Crying'),
             ('😡', '화남', 'Angry'), ('🤡', '광대', 'Clown'), ('😺', '웃는 고양이', 'Smiling Cat'), ('🙈', '안 보여', 'See-No-Evil'),
             ('💩', '응가', 'Poop'), ('🥶', '꽁꽁', 'Freezing'), ('🤓', '안경', 'Nerd'), ('😷', '마스크', 'Mask')],
    'wear': [('👕', '티셔츠', 'T-Shirt'), ('👗', '원피스', 'Dress'), ('👟', '운동화', 'Sneaker'), ('👠', '하이힐', 'High Heel'),
             ('🎩', '중절모', 'Top Hat'), ('🧢', '야구모자', 'Cap'), ('👒', '밀짚모자', 'Sun Hat'), ('🧤', '장갑', 'Gloves'),
             ('🧦', '양말', 'Socks'), ('👜', '핸드백', 'Handbag'), ('🎒', '책가방', 'Backpack'), ('👓', '안경', 'Glasses'),
             ('💍', '반지', 'Ring'), ('🧣', '목도리', 'Scarf'), ('👘', '기모노', 'Kimono'), ('🥾', '등산화', 'Hiking Boot')],
}

# 한 레벨 안의 색은 이 값(CIELAB 거리) 이상 떨어져 있어야 눈으로 구분됩니다.
MIN_DE = 23

font = ImageFont.truetype(FONT, 109)


def render(ch):
    im = Image.new('RGBA', (300, 160), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((10, 10), ch, font=font, embedded_color=True)
    bb = im.getbbox()
    if bb is None or bb[2] - bb[0] > 150:
        return None
    im = im.crop(bb)
    s = max(im.size)
    sq = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    sq.paste(im, ((s - im.width) // 2, (s - im.height) // 2))
    return sq


def rgb2lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def pixelize(sq, n, maxk, rng, min_de=MIN_DE):
    a = np.asarray(sq).astype(np.float64)
    s = a.shape[0]
    big = n * 8
    im = Image.fromarray(a.astype(np.uint8)).resize((big, big), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64)
    al = a[:, :, 3:4] / 255.0
    pm = a[:, :, :3] * al
    pm = pm.reshape(n, 8, n, 8, 3).sum(axis=(1, 3))
    asum = al.reshape(n, 8, n, 8, 1).sum(axis=(1, 3))
    mask = (asum[:, :, 0] / 64.0) > 0.45
    rgb = pm / np.maximum(asum, 1e-6)
    pts = rgb[mask]
    if len(pts) < 12:
        return None
    # 명암·채도 대비를 키워 음영이 서로 다른 색으로 또렷이 갈리게 합니다.
    lum = pts @ np.array([0.299, 0.587, 0.114])
    pts = lum[:, None] + (pts - lum[:, None]) * 1.25
    pts = np.clip(pts.mean(0) + (pts - pts.mean(0)) * 1.3, 0, 255)
    lab = rgb2lab(pts)
    # k-means (k-means++ 초기화)
    k = min(maxk + 2, len(pts))
    cent = [lab[rng.integers(len(lab))]]
    for _ in range(k - 1):
        d = np.min([((lab - c) ** 2).sum(1) for c in cent], axis=0)
        cent.append(lab[rng.choice(len(lab), p=d / d.sum())] if d.sum() > 0 else lab[0])
    cent = np.array(cent)
    for _ in range(30):
        lab_idx = ((lab[:, None, :] - cent[None]) ** 2).sum(2).argmin(1)
        for i in range(len(cent)):
            if (lab_idx == i).any():
                cent[i] = lab[lab_idx == i].mean(0)
    # 가까운/작은 클러스터 병합
    while True:
        lab_idx = ((lab[:, None, :] - cent[None]) ** 2).sum(2).argmin(1)
        cnt = np.bincount(lab_idx, minlength=len(cent))
        keep = cnt > 0
        cent = cent[keep]
        lab_idx = ((lab[:, None, :] - cent[None]) ** 2).sum(2).argmin(1)
        cnt = np.bincount(lab_idx, minlength=len(cent))
        if len(cent) <= 2:
            break
        dm = np.sqrt(((cent[:, None] - cent[None]) ** 2).sum(2)) + np.eye(len(cent)) * 1e9
        i, j = np.unravel_index(dm.argmin(), dm.shape)
        small = cnt.argmin()
        if dm[i, j] < min_de or len(cent) > maxk:
            w = cnt[i] + cnt[j]
            cent[i] = (cent[i] * cnt[i] + cent[j] * cnt[j]) / w
            cent = np.delete(cent, j, 0)
        elif cnt[small] < max(3, 0.025 * len(pts)):
            cent = np.delete(cent, small, 0)
        else:
            break
    lab_idx = ((lab[:, None, :] - cent[None]) ** 2).sum(2).argmin(1)
    pal = []
    for i in range(len(cent)):
        c = pts[lab_idx == i].mean(0)
        # 채도를 살짝 올려 블록 색이 또렷하게 보이도록 함
        c = np.clip(c, 0, 255)
        pal.append('%02x%02x%02x' % tuple(int(round(v)) for v in c))
    grid = -np.ones((n, n), dtype=int)
    grid[mask] = lab_idx
    # 빈 가장자리 제거
    ys, xs = np.where(grid >= 0)
    grid = grid[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    rows = [''.join('.' if v < 0 else chr(ord('a') + v) for v in r) for r in grid]
    return {'w': grid.shape[1], 'h': grid.shape[0], 'pal': pal, 'rows': rows}


def size_for(level):
    """레벨 → (격자 크기, 최대 색 수, 최소 색 거리). 뒤로 갈수록 크고 색이 많아집니다."""
    if level <= 4:
        return 10, 3, MIN_DE
    if level <= 12:
        return 12, 4, MIN_DE
    if level <= 30:
        return 15, 5, MIN_DE
    if level <= 70:
        return 18, 6, 20
    if level <= 130:
        return 21, 7, 18
    if level <= 200:
        return 24, 8, 16
    return 26, 9, 16


def main():
    # 카테고리를 돌아가며 섞어 레벨 순서를 정함 (고정 시드)
    r = random.Random(20261112)
    pools = {c: list(v) for c, v in T.items()}
    for v in pools.values():
        r.shuffle(v)
    # 초반은 음식 위주로 시작
    order = []
    cats = [c[0] for c in CATS]
    while any(pools.values()):
        live = [c for c in cats if pools[c]]
        r.shuffle(live)
        live.sort(key=lambda c: -len(pools[c]))
        for c in live[:max(6, len(live) // 2)]:
            order.append((c,) + pools[c].pop())
    # 첫 레벨들은 저해상도에서도 알아보기 쉬운 그림으로 고정
    starters = ['❤️', '🍎', '⭐', '🍉', '🐤', '🍩', '🐸', '🍓', '🎃', '🍔', '🐼', '🌈']
    flat = {t[0]: (c,) + t for c, v in T.items() for t in v}
    order = [flat[s] for s in starters] + order
    seen = set()
    themes = []
    rng = np.random.default_rng(7)
    for cat, ch, ko, en in order:
        if ch in seen:
            continue
        seen.add(ch)
        sq = render(ch)
        if sq is None:
            print('skip (no glyph):', en, file=sys.stderr)
            continue
        n, k, de = size_for(len(themes) + 1)
        p = pixelize(sq, n, k, rng, de)
        if p is None or len(p['pal']) < 2:
            print('skip (flat):', en, file=sys.stderr)
            continue
        themes.append({'id': en.lower().replace(' ', '_').replace('&', 'n'), 'cat': cat, 'ko': ko, 'en': en, 'src': ch, **p})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = {'cats': [{'id': c, 'ko': k, 'en': e} for c, k, e in CATS], 'themes': themes}
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')))
    print(len(themes), 'themes ->', OUT, OUT.stat().st_size, 'bytes')
    if '--sheet' in sys.argv:
        out = sys.argv[sys.argv.index('--sheet') + 1]
        cols, cell = 16, 112
        rows = (len(themes) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * cell, rows * cell), (30, 32, 48))
        d = ImageDraw.Draw(sheet)
        for i, t in enumerate(themes):
            ox, oy = (i % cols) * cell + 4, (i // cols) * cell + 4
            px = 104 // max(t['w'], t['h'])
            for y, row in enumerate(t['rows']):
                for x, c in enumerate(row):
                    if c != '.':
                        h = t['pal'][ord(c) - 97]
                        col = tuple(int(h[j:j + 2], 16) for j in (0, 2, 4))
                        d.rectangle([ox + x * px, oy + y * px, ox + x * px + px - 2, oy + y * px + px - 2], fill=col)
        sheet.save(out)


if __name__ == '__main__':
    main()
