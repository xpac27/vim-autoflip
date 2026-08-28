#include <vector>

enum class IntegrationState { Ready };

void autoflip_integration_fixture() {
  std::vector<int> values;
  std::vector<int>::iterator it = values.begin();
  auto answer = 42;
  IntegrationState state = IntegrationState::Ready;
  IntegrationState copied = state;
  IntegrationState copied_again = copied;
}
