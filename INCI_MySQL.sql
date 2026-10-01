# 1. Risk distribution across all the ingredients
# Results: Only 1% of the ingredients (16 of 1,560) are in the high-risk category.
select 
	coalesce(risk,'total') risk, 
    count(*) as ingredients,
    concat(round(count(*)/(select count(*) from ingredient)*100,2),'%') pct_distro
from ingredient
group by risk with rollup
order by grouping(risk), ingredients desc;


# 2. Which product categories have the highest share of high-risk products?
# Results: Sunscreen has the highest share of high-risk products (3.1%), but that's only 1 product out of 32.
# Makeup has the most high-risk products (4). I also have the most products in makeup, and it has the highest average EWG score (3.9).
# Overall, the bigger categories tend to have more high-risk products and higher average EWG scores, but it's not a perfect pattern.

select
coalesce(category,'Total') category,
sum(case when ewg <= 3 then 1 else 0 end) as low_risk,
sum(case when ewg between 4 and 7 then 1 else 0 end) as medium_risk,
sum(case when ewg >= 8 then 1 else 0 end) as high_risk,
count(*) as total_product,
round(avg(ewg),1) as avg_ewg,
concat(Round(SUM(case when ewg <= 3 then 1 else 0 end) / COUNT(*) * 100, 1),'%') AS low_risk_pct,
concat(ROUND(SUM(case when ewg between 4 and 7 then 1 else 0 end) / COUNT(*) * 100, 1),'%') AS medium_risk_pct,
concat(ROUND(SUM(case when ewg >= 8 then 1 else 0 end) / COUNT(*) * 100, 1),'%') AS high_risk_pct
from product
group by category with rollup
order by grouping(category), sum(case when ewg >= 8 then 1 else 0 end) / count(*) desc, avg(ewg) desc;


# 3. For brands with at least 5 products, how many of their products are medium or high risk (EWG 4 or higher)?
# Results: Dior and Shiseido have the highest average EWG scores (about 6.5), and every one of their products is medium or high risk.
# SKIN1004, Good Molecules and e.l.f. have the lowest (2.2 to 2.3).
select
brand,
count(*) as n_product,
sum(ewg >= 4) as medium_high_products,
round(sum(ewg >= 4) / count(*) * 100, 1) as pct_medium_high,
round(avg(ewg),2) as avg_ewg
from product
group by brand
having count(*) >= 5
order by avg_ewg desc, n_product desc;

# 4. Which ingredients appear most often across products (top 15)?
# Results: The most common ingredients all have low EWG scores. Water is in 288 products and glycerin is in 231.
select
pi.ing_id,
i.ingredient_standard,
i.ewg,
count(distinct pi.pro_id) as n_product
from product_ingredient pi
join ingredient i on pi.ing_id = i.ing_id
group by pi.ing_id, i.ingredient_standard,i.ewg
order by count(distinct pi.pro_id) desc
limit 15;

# 5. Which ingredients have a high EWG rating (EWG 8 or higher)?
# Results: This list helped me decide which ingredients to avoid. I tend to avoid ingredients with a high EWG score (8 or higher) and a small EWG gap (2 or less).
# A bigger EWG gap means the risk depends on the product formulation (powder vs. liquid).
# Take Carbon Black as an example. It's high risk in powder form, but all of my makeup products with carbon black are in liquid form. That lowers the health risk a lot, which is why I don't avoid this ingredient.
# I don't avoid most retinoids, even with their high EWG scores. They're one of the best-proven anti-aging ingredients, and the concentration in cosmetic products is low.
# Retinyl Palmitate is the exception. It's on Sephora's Clean Beauty list of ingredients a product must be made without, and none of the other retinoids are on that list.
# A 2012 study also found it sped up skin tumors in mice exposed to UV light. In my products it shows up in lipsticks and an eye primer I wear during the day, not in anti-aging treatments, so I'd rather skip it.
select 
i.ingredient_standard,
ewg_min,
ewg_max,
count(distinct pi.pro_id) n_product,
ewg_max-ewg_min as ewg_gap,
carcinogen,
cancer,
avoid
from ingredient i
left join product_ingredient pi on pi.ing_id=i.ing_id
where ewg_max >=8
group by i.ingredient_standard, ewg_min, ewg_max, carcinogen, cancer,avoid
order by ewg_max desc, ewg_gap desc, n_product desc;

# 6. Which products contain high-risk ingredients (EWG 8 or higher)?
# Results: 110 products contain at least one high-risk ingredient.
# I was surprised to see that more than a quarter of the products I use (28%) contain these ingredients.
select
p.pro_id,
p.product_name,
p.category,
p.ewg as product_ewg,
count(pi.ing_id) as high_risk_ingredient,
round(avg(i.ewg_max),2) as avg_ewg_high_risk_ing,
group_concat(distinct i.ingredient_standard order by i.ingredient_standard separator ', ') as high_risk_ingredients
from product p
join product_ingredient pi on p.pro_id = pi.pro_id
join ingredient i on pi.ing_id = i.ing_id
where i.ewg_max >= 8
group by p.pro_id, p.product_name, p.category, p.ewg
order by high_risk_ingredient desc, avg_ewg_high_risk_ing desc;

# 7. How are fragranced products spread across each category?
# Results: In every category that has fragranced products, they have a higher average EWG score than the ones without fragrance.
# Overall it's 5.56 with fragrance vs. 3.15 without. Skincare has the biggest gap (6.21 vs. 3.07), and haircare has the most fragranced products (39%).
select
coalesce(category,"Total") as category,
count(*) as total_products,
count(case when contain_fragrance = "True" then 1 end) as fragrance_product,
count(case when contain_fragrance = "False" then 1 end) as no_fragrance_product,
round(count(case when contain_fragrance = "True" then 1 end)/count(*) *100,2)as fragrance_percentage,
round(avg(ewg),2) as avg_ewg,
round(avg(case when contain_fragrance = "False" then ewg end),2) as avg_ewg_no_fragrance,
round(avg(case when contain_fragrance = "True" then ewg end),2) as avg_ewg_fragrance,
round(avg(case when contain_fragrance = "True" then ewg end),2) -
round(avg(case when contain_fragrance = "False" then ewg end),2) as gap_avg_ewg
from product p
group by category with rollup
order by grouping(category), avg_ewg_fragrance desc;


# 8a. What percentage of products in each category contain ingredients I avoid, and how does that affect their average EWG scores?
# Results: 36% of my products (141) contain at least one ingredient I avoid. They average 4.50 vs. 2.96 for products without them, and they score higher in every category.
# Haircare has the highest share at 58%.
select
coalesce(category,"Total") as category,
count(*) as total_product,
sum(n_avoid > 0) as avoid_products,
round(sum(n_avoid > 0)/count(*)*100,2) as avoid_percentage,
round(avg(case when n_avoid > 0 then ewg end),2) as avg_ewg_avoid,
round(avg(case when n_avoid = 0 then ewg end),2) as avg_ewg_no_avoid
from product
group by category with rollup
order by grouping (category), avoid_products desc;


# 8b. Which ingredients I avoid show up in the most products, and what are their risk profiles?
# Results: There are 39 ingredients I avoid, and fragrance is in the most products (59).
# I avoid ingredients with an ewg_max of 10, except carbon black. It's the only one of those 5 ingredients with an ewg_min of 3, which makes its EWG gap bigger. That means its safety depends on more variables.
# I also avoid ingredients that can disrupt hormones (preservatives like BHT and parabens).
# Synthetic ureas can release formaldehyde, so I avoid those as well.
# I avoid ingredients that I know break me out, like biotin, VP polymers and glyceryl dioleate, even though they have low EWG scores.

select
i.ingredient_standard,
i.ewg_max,
i.hormone,
i.carcinogen,
i.cancer,
i.acne,
count(distinct pi.pro_id) as products,
round(avg(p.ewg),2) as avg_product_ewg
from ingredient i
join product_ingredient pi on pi.ing_id = i.ing_id
join product p on p.pro_id = pi.pro_id
where avoid = 'yes'
group by i.ingredient_standard, i.ewg_max, i.hormone,i.cancer, i.carcinogen, i.acne
order by products desc, ewg_max desc;


# 9. Do more ingredients lead to a higher EWG rating?
# Results: It does seem like the average EWG score goes up as the ingredient count goes up, from 1.94 for 1-10 ingredients to 4.37 for 31+.

SELECT
    CASE
        WHEN n_ingredient <= 10 THEN '01: 1-10 Ingredients'
        WHEN n_ingredient <= 20 THEN '02: 11-20 Ingredients'
        WHEN n_ingredient <= 30 THEN '03: 21-30 Ingredients'
        ELSE '04: 31+ Ingredients'
    END AS ingredient_bracket,
    COUNT(*) AS product_count,
    ROUND(AVG(ewg), 2) AS avg_ewg_rating,
    MIN(ewg) AS lowest_ewg,
    MAX(ewg) AS highest_ewg
FROM product
GROUP BY 1
ORDER BY 1 ASC;



# 10a. What percentage of my products contain carcinogens? Compare by category, and compare the average EWG with vs. without.
# Results: 36.5% of my products contain at least one carcinogenic ingredient, so I dig into what those ingredients are in 10b.
# Makeup has by far the highest share (82.9%).

select
coalesce(category,'total') as category,
count(*) as total_products,
sum(n_carcinogen > 0) as carcinogen_products,
round(sum(n_carcinogen > 0) / count(*) * 100, 1) as pct_carcinogen,
round(avg(case when n_carcinogen > 0 then ewg end),2) as avg_ewg_with,
round(avg(case when n_carcinogen = 0 then ewg end),2) as avg_ewg_without
from product
group by category with rollup
order by isnull(category), pct_carcinogen desc;

# 10b. Which carcinogenic ingredients are in my products?
# Results: Only 3 carcinogenic ingredients show up in my products, and I'm not too concerned about 2 of them (Titanium Dioxide and Carbon Black).
select
i.ingredient_standard,
i.ewg,
i.risk,
i.cancer as ewg_cancer_concern,
count(distinct p.pro_id) as products
from ingredient i
join product_ingredient pi on pi.ing_id = i.ing_id
join product p on p.pro_id = pi.pro_id
where i.carcinogen = 'yes'
group by i.ing_id, i.ingredient_standard, i.ewg, i.risk, i.cancer
order by products desc;

