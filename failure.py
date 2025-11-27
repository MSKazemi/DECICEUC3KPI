from statistics import mean, variance

data = [332.825, 336.853, 343.199, 349.737, 344.205]

mean_val = mean(data)
variance_val = variance(data)

print(f"Mean: {mean_val}")
print(f"Variance: {variance_val}")