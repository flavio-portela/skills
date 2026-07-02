# Common Simplification Patterns

## Redundant Conditional

```javascript
// Before
if (isValid === true) {
  return true;
} else {
  return false;
}

// After
return isValid;
```

## Verbose Array Processing

```javascript
// Before
const result = [];
for (const item of items) {
  if (item.active) {
    result.push(item);
  }
}

// After
const result = items.filter(item => item.active);
```

## Deep Nesting via Early Return

```python
# Before
def process(user):
    if user:
        if user.is_active:
            if user.has_permission:
                return do_thing(user)
            else:
                return None
        else:
            return None
    else:
        return None

# After
def process(user):
    if not user or not user.is_active or not user.has_permission:
        return None
    return do_thing(user)
```

## Dead Code Removal

```typescript
// Before
import { formatDate, parseCSV, unusedHelper } from './utils';

const MAX_RETRIES = 3;
const DEPRECATED_LIMIT = 100; // no longer used

export function submit(data) {
  const retries = 0; // assigned but never read
  return api.post('/submit', data);
}

// After
import { formatDate, parseCSV } from './utils';

export function submit(data) {
  return api.post('/submit', data);
}
```

## Function Extraction for Repeated Logic

```javascript
// Before
if (user.role === 'admin' && user.status === 'active') {
  // 15 lines of permission setup
}
// ... later ...
if (user.role === 'admin' && user.status === 'active') {
  // same 15 lines of permission setup
}

// After
function isAdminActive(user) {
  return user.role === 'admin' && user.status === 'active';
}

function setupAdminPermissions(user) {
  // 15 lines of permission setup
}

if (isAdminActive(user)) {
  setupAdminPermissions(user);
}
// ... later ...
if (isAdminActive(user)) {
  setupAdminPermissions(user);
}
```

## TOCTOU Anti-Pattern

```python
# Before
if os.path.exists(filepath):
    data = open(filepath).read()

# After
try:
    with open(filepath) as f:
        data = f.read()
except FileNotFoundError:
    data = None
```

## Redundant State

```javascript
// Before
const [items, setItems] = useState([]);
const [filteredItems, setFilteredItems] = useState([]);

// filteredItems is manually synced whenever items or filter changes
useEffect(() => {
  setFilteredItems(items.filter(item => matchesFilter(item)));
}, [items, filter]);

// After
const [items, setItems] = useState([]);
const filteredItems = useMemo(() => items.filter(item => matchesFilter(item)), [items, filter]);
```
