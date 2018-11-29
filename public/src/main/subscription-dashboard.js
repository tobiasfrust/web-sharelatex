/* eslint-disable
    camelcase,
    max-len,
    no-return-assign,
    no-undef,
    no-unused-vars,
*/
// TODO: This file was created by bulk-decaffeinate.
// Fix any style issues and re-enable lint.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS104: Avoid inline assignments
 * DS204: Change includes calls to have a more natural evaluation order
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
define(['base'], function(App) {
  const SUBSCRIPTION_URL = '/user/subscription/update'

  const ensureRecurlyIsSetup = _.once(() => {
    if (!recurly) return
    recurly.configure(window.recurlyApiKey)
  })

  App.factory('RecurlyPricing', function($q, MultiCurrencyPricing) {
    return {
      loadDisplayPriceWithTax: function(planCode, currency, taxRate) {
        ensureRecurlyIsSetup()
        const currencySymbol = MultiCurrencyPricing.plans[currency].symbol
        const pricing = recurly.Pricing()
        return $q(function(resolve, reject) {
          pricing
            .plan(planCode, { quantity: 1 })
            .currency(currency)
            .done(function(price) {
              const totalPriceExTax = parseFloat(price.next.total)
              let taxAmmount = totalPriceExTax * taxRate
              if (isNaN(taxAmmount)) {
                taxAmmount = 0
              }
              resolve(`${currencySymbol}${totalPriceExTax + taxAmmount}`)
            })
        })
      }
    }
  })

  App.controller('ChangePlanFormController', function(
    $scope,
    $modal,
    RecurlyPricing
  ) {
    ensureRecurlyIsSetup()

    $scope.changePlan = () =>
      $modal.open({
        templateUrl: 'confirmChangePlanModalTemplate',
        controller: 'ConfirmChangePlanController',
        scope: $scope
      })

    $scope.$watch('plan', function(plan) {
      if (!plan) return
      const planCode = plan.planCode
      const { currency, taxRate } = window.subscription.recurly
      $scope.price = '...' // Placeholder while we talk to recurly
      RecurlyPricing.loadDisplayPriceWithTax(planCode, currency, taxRate).then(
        price => {
          $scope.price = price
        }
      )
    })
  })

  App.controller('ConfirmChangePlanController', function(
    $scope,
    $modalInstance,
    $http
  ) {
    $scope.confirmChangePlan = function() {
      const body = {
        plan_code: $scope.plan.planCode,
        _csrf: window.csrfToken
      }

      $scope.inflight = true

      return $http
        .post(`${SUBSCRIPTION_URL}?origin=confirmChangePlan`, body)
        .then(() => location.reload())
        .catch(() => console.log('something went wrong changing plan'))
    }

    return ($scope.cancel = () => $modalInstance.dismiss('cancel'))
  })

  App.controller('LeaveGroupModalController', function(
    $scope,
    $modalInstance,
    $http
  ) {
    $scope.confirmLeaveGroup = function() {
      $scope.inflight = true
      return $http({
        url: '/subscription/group/user',
        method: 'DELETE',
        params: { admin_user_id: $scope.admin_id, _csrf: window.csrfToken }
      })
        .then(() => location.reload())
        .catch(() => console.log('something went wrong changing plan'))
    }

    return ($scope.cancel = () => $modalInstance.dismiss('cancel'))
  })

  App.controller('GroupMembershipController', function($scope, $modal) {
    $scope.removeSelfFromGroup = function(admin_id) {
      $scope.admin_id = admin_id
      return $modal.open({
        templateUrl: 'LeaveGroupModalTemplate',
        controller: 'LeaveGroupModalController',
        scope: $scope
      })
    }
  })

  App.controller('RecurlySubscriptionController', function($scope) {
    $scope.showChangePlanButton = !subscription.groupPlan

    $scope.switchToDefaultView = () => {
      $scope.showCancellation = false
      $scope.showChangePlan = false
    }
    $scope.switchToDefaultView()

    $scope.switchToCancellationView = () => {
      $scope.showCancellation = true
      $scope.showChangePlan = false
    }

    $scope.switchToChangePlanView = () => {
      $scope.showCancellation = false
      $scope.showChangePlan = true
    }
  })

  App.controller('RecurlyCancellationController', function(
    $scope,
    RecurlyPricing,
    $http
  ) {
    const subscription = window.subscription
    const sevenDaysTime = new Date()
    sevenDaysTime.setDate(sevenDaysTime.getDate() + 7)
    const freeTrialEndDate = new Date(subscription.recurly.trial_ends_at)
    const freeTrialInFuture = freeTrialEndDate > new Date()
    const freeTrialExpiresUnderSevenDays = freeTrialEndDate < sevenDaysTime

    const isMonthlyCollab =
      subscription.plan.planCode.indexOf('collaborator') !== -1 &&
      subscription.plan.planCode.indexOf('ann') === -1 &&
      !subscription.groupPlan
    const stillInFreeTrial = freeTrialInFuture && freeTrialExpiresUnderSevenDays

    if (isMonthlyCollab && stillInFreeTrial) {
      $scope.showExtendFreeTrial = true
    } else if (isMonthlyCollab && !stillInFreeTrial) {
      $scope.showDowngradeToStudent = true
    } else {
      $scope.showBasicCancel = true
    }

    const { currency, taxRate } = window.subscription.recurly
    $scope.studentPrice = '...' // Placeholder while we talk to recurly
    RecurlyPricing.loadDisplayPriceWithTax('student', currency, taxRate).then(
      price => {
        $scope.studentPrice = price
      }
    )

    $scope.downgradeToStudent = function() {
      const body = {
        plan_code: 'student',
        _csrf: window.csrfToken
      }
      $scope.inflight = true
      return $http
        .post(`${SUBSCRIPTION_URL}?origin=downgradeToStudent`, body)
        .then(() => location.reload())
        .catch(() => console.log('something went wrong changing plan'))
    }

    $scope.cancelSubscription = function() {
      const body = { _csrf: window.csrfToken }

      $scope.inflight = true
      return $http
        .post('/user/subscription/cancel', body)
        .then(() => location.reload())
        .catch(() => console.log('something went wrong changing plan'))
    }

    $scope.extendTrial = function() {
      const body = { _csrf: window.csrfToken }
      $scope.inflight = true
      return $http
        .put('/user/subscription/extend', body)
        .then(() => location.reload())
        .catch(() => console.log('something went wrong changing plan'))
    }
  })
})
