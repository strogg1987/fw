#include "FreeRTOS.h"
#include "task.h"
// #include "queue.h"
// #include "semphr.h"

#include <libopencm3/stm32/g0/rcc.h>
#include <libopencm3/stm32/g0/gpio.h>

// /*
//  * Handler in case our application overflows the stack
//  */
// void vApplicationStackOverflowHook(
//     TaskHandle_t xTask __attribute__((unused)),
//     char *pcTaskName __attribute__((unused)))
// {

//     for (;;)
//         ;
// }

static void
task1(void *args)
{
    int i;

    (void)args;

    for (;;)
    {
        gpio_toggle(GPIOC, GPIO13);
        for (i = 0; i < 1000000; i++)
            __asm__("nop");
    }
}

int main(void)
{
    rcc_clock_setup(&rcc_clock_config[RCC_CLOCK_CONFIG_HSI_PLL_64MHZ]);
    rcc_periph_clock_enable(RCC_GPIOC);
    gpio_mode_setup(GPIOC, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO13);

    xTaskCreate(task1, "LED", 100, NULL, configMAX_PRIORITIES - 1, NULL);
    vTaskStartScheduler();
    for (;;)
        ;

    return 0;
}