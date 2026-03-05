def original_logic(results):
    res = [dict(r) for r in results]
    for i in range(len(res)):
        if res[i]['code'] is None:
            backward = None
            for j in range(i - 1, -1, -1):
                if res[j]['code'] is not None:
                    backward = res[j]['code']
                    break

            forward = None
            for j in range(i + 1, len(res)):
                if res[j]['code'] is not None:
                    forward = res[j]['code']
                    break

            res[i]['suggestions'] = [backward, forward]
    return res

def optimized_logic(results):
    res = [dict(r) for r in results]
    backward_suggestions = [None] * len(res)
    current_backward = None
    for i in range(len(res)):
        backward_suggestions[i] = current_backward
        if res[i]['code'] is not None:
            current_backward = res[i]['code']

    forward_suggestions = [None] * len(res)
    current_forward = None
    for i in range(len(res) - 1, -1, -1):
        forward_suggestions[i] = current_forward
        if res[i]['code'] is not None:
            current_forward = res[i]['code']

    for i in range(len(res)):
        if res[i]['code'] is None:
            res[i]['suggestions'] = [backward_suggestions[i], forward_suggestions[i]]

    return res

test_data = [
    {'code': 'US'},
    {'code': None},
    {'code': None},
    {'code': 'FR'},
    {'code': None},
    {'code': 'UK'},
    {'code': None},
]

orig = original_logic(test_data)
opt = optimized_logic(test_data)

assert orig == opt
print("Success!")
